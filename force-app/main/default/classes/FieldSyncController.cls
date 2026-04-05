public class FieldSyncController {

    private static final Set<String> SYSTEM_FIELD_EXCLUSIONS = new Set<String>{
        'id', 'systemmodstamp', 'isdeleted', 'lastactivitydate', 'lastvieweddate', 'lastreferenceddate'
    };

    private static final Set<String> ALWAYS_REQUIRED_READONLY = new Set<String>{
        'createddate', 'createdbyid', 'lastmodifieddate', 'lastmodifiedbyid', 'ownerid'
    };

    private static final Set<Schema.DisplayType> EXCLUDED_TYPES = new Set<Schema.DisplayType>{
        Schema.DisplayType.Address,
        Schema.DisplayType.Location,
        Schema.DisplayType.Base64,
        Schema.DisplayType.EncryptedString
    };

    @AuraEnabled
    public static FormWrappers.SyncResultWrapper syncFields(String objectMappingId) {
        Custom_Object_Mapping__c mapping = [
            SELECT Object_API_Name__c, Page_Layout_ID__c
            FROM Custom_Object_Mapping__c
            WHERE Id = :objectMappingId
            LIMIT 1
        ];

        String nc = System.Label.Tooling_API_Named_Credential;

        // Verify the layout belongs to the configured object
        String verifyQuery = 'SELECT Id FROM Layout WHERE Id = \''
            + String.escapeSingleQuotes(mapping.Page_Layout_ID__c)
            + '\' AND EntityDefinition.QualifiedApiName = \''
            + String.escapeSingleQuotes(mapping.Object_API_Name__c) + '\'';
        String verifyEndpoint = 'callout:' + nc + '/services/data/v66.0/tooling/query?q='
            + EncodingUtil.urlEncode(verifyQuery, 'UTF-8');
        HttpRequest verifyReq = new HttpRequest();
        verifyReq.setMethod('GET');
        verifyReq.setEndpoint(verifyEndpoint);
        HttpResponse verifyRes = new Http().send(verifyReq);
        Map<String, Object> verifyBody = (Map<String, Object>) JSON.deserializeUntyped(verifyRes.getBody());
        List<Object> verifyRecords = (List<Object>) verifyBody.get('records');
        if (verifyRecords == null || verifyRecords.isEmpty()) {
            throw new AuraHandledException('Layout does not belong to object '
                + mapping.Object_API_Name__c + '. Please re-select the layout.');
        }

        String endpoint = 'callout:' + nc + '/services/data/v66.0/tooling/sobjects/Layout/'
            + mapping.Page_Layout_ID__c;

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Tooling API error: ' + res.getStatus());
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> metadata = (Map<String, Object>) body.get('Metadata');

        // Describe schema first so compound expansion can use it
        Map<String, Schema.SObjectField> schemaFields = Schema.getGlobalDescribe()
            .get(mapping.Object_API_Name__c).getDescribe().fields.getMap();

        // Parse layout sections: all layout items use 'field' — compound fields like Name
        // and Address appear as field values (e.g. "field":"Name", "field":"Address"),
        // not as component values. We collect them all here and expand compounds below.
        Map<String, String> fieldToSection = new Map<String, String>();

        List<Object> sections = (List<Object>) metadata.get('layoutSections');
        System.debug('=== LAYOUT SECTIONS ===');
        System.debug(JSON.serialize(sections));
        if (sections != null) {
            for (Object sec : sections) {
                Map<String, Object> section = (Map<String, Object>) sec;
                String sectionLabel = (String) section.get('label');
                List<Object> columns = (List<Object>) section.get('layoutColumns');
                if (columns == null) continue;
                for (Object col : columns) {
                    Map<String, Object> column = (Map<String, Object>) col;
                    List<Object> items = (List<Object>) column.get('layoutItems');
                    if (items == null) continue;
                    for (Object item : items) {
                        Map<String, Object> layoutItem = (Map<String, Object>) item;
                        String fieldName = (String) layoutItem.get('field');
                        if (String.isNotBlank(fieldName)) {
                            fieldToSection.put(fieldName, sectionLabel);
                        }
                    }
                }
            }
        }

        // Ensure Name compound is present even if the layout omitted it
        Schema.SObjectField nameSof = schemaFields.get('name');
        if (nameSof != null && !fieldToSection.containsKey('Name')) {
            fieldToSection.put('Name', 'Information');
        }

        // Expand compound field references: the layout stores compound names as field values
        // (e.g. "Name" → expands to FirstName, LastName; "Address" → Street, City, etc.).
        // Any schema field whose getCompoundFieldName() matches a key in fieldToSection
        // is a sub-field of that compound — add it with the compound's section label.
        for (String apiNameLower : schemaFields.keySet()) {
            Schema.DescribeFieldResult dfr = schemaFields.get(apiNameLower).getDescribe();
            String compound = dfr.getCompoundFieldName();
            if (String.isNotBlank(compound) && fieldToSection.containsKey(compound)) {
                String fieldApiName = dfr.getName();
                if (!fieldToSection.containsKey(fieldApiName)) {
                    fieldToSection.put(fieldApiName, fieldToSection.get(compound));
                }
            }
        }

        // Load existing mappings into map by field API name
        Map<String, Custom_Field_Mapping__c> existingByApiName = new Map<String, Custom_Field_Mapping__c>();
        for (Custom_Field_Mapping__c cfm : [
            SELECT Id, Field_API_Name__c
            FROM Custom_Field_Mapping__c
            WHERE Object_Mapping__c = :objectMappingId
        ]) {
            existingByApiName.put(cfm.Field_API_Name__c, cfm);
        }

        // incomingFields is built only from fields that pass all schema checks.
        // Fields that fail (no schema entry, excluded type, not editable) are excluded,
        // so stale DB records for those fields will be cleaned up in the delete pass.
        Set<String> incomingFields = new Set<String>();
        List<Custom_Field_Mapping__c> toInsert = new List<Custom_Field_Mapping__c>();
        List<Custom_Field_Mapping__c> toDelete = new List<Custom_Field_Mapping__c>();
        Integer unchanged = 0;

        for (String fieldName : fieldToSection.keySet()) {
            String fieldNameLower = fieldName.toLowerCase();
            if (SYSTEM_FIELD_EXCLUSIONS.contains(fieldNameLower)) continue;

            Boolean isAlwaysRequired = ALWAYS_REQUIRED_READONLY.contains(fieldNameLower);
            Schema.SObjectField sof = schemaFields.get(fieldNameLower);
            if (sof == null && !isAlwaysRequired) continue;
            Boolean isReadOnly = isAlwaysRequired;

            if (!isAlwaysRequired && sof != null) {
                Schema.DescribeFieldResult dfr = sof.getDescribe();

                if (EXCLUDED_TYPES.contains(dfr.getType())) continue;

                if (dfr.isCalculated() || dfr.isAutoNumber()) {
                    isReadOnly = true;
                } else if (!dfr.isUpdateable() && !dfr.isCreateable()) {
                    continue;
                }
            }

            // Field passed all checks — track it as a valid incoming field
            incomingFields.add(fieldName);

            if (existingByApiName.containsKey(fieldName)) {
                unchanged++;
            } else {
                String fieldType = 'Text';
                String referenceTo = null;
                Boolean isRequired = isAlwaysRequired;
                String fieldLabel = fieldName;

                if (sof != null) {
                    Schema.DescribeFieldResult dfr = sof.getDescribe();
                    fieldType = dfr.getType().name();
                    fieldLabel = dfr.getLabel();
                    if (!isAlwaysRequired) {
                        isRequired = !dfr.isNillable() && !dfr.isDefaultedOnCreate();
                    }
                    List<Schema.SObjectType> refs = dfr.getReferenceTo();
                    for (Schema.SObjectType ref : refs) {
                        String refName = ref.getDescribe().getName();
                        if (refName == 'User') {
                            referenceTo = 'User';
                            break;
                        }
                    }
                    if (referenceTo == null && !refs.isEmpty()) {
                        referenceTo = refs[0].getDescribe().getName();
                    }
                }

                toInsert.add(new Custom_Field_Mapping__c(
                    Object_Mapping__c = objectMappingId,
                    Field_API_Name__c = fieldName,
                    Field_Label__c = fieldLabel,
                    Field_Type__c = fieldType,
                    Is_Required_Layout__c = isRequired,
                    Is_Read_Only__c = isReadOnly,
                    Is_Always_Required__c = isAlwaysRequired,
                    Reference_To__c = referenceTo,
                    Section_Label__c = fieldToSection.get(fieldName),
                    Default_Visibility__c = 'Visible',
                    Is_Active__c = true
                ));
            }
        }

        for (String fieldName : existingByApiName.keySet()) {
            if (!incomingFields.contains(fieldName)) {
                toDelete.add(existingByApiName.get(fieldName));
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toDelete.isEmpty()) delete toDelete;

        FormWrappers.SyncResultWrapper result = new FormWrappers.SyncResultWrapper();
        result.added = toInsert.size();
        result.removed = toDelete.size();
        result.unchanged = unchanged;
        return result;
    }
}
