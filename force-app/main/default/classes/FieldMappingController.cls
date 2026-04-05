public class FieldMappingController {

    @AuraEnabled
    public static List<FormWrappers.FieldConfigWrapper> getFieldMappings(String objectMappingId) {
        List<FormWrappers.FieldConfigWrapper> result = new List<FormWrappers.FieldConfigWrapper>();

        for (Custom_Field_Mapping__c fm : [
            SELECT Id, Field_API_Name__c, Field_Label_Override__c,
                Field_Type__c, Field_Subtype__c, Address_Group__c,
                Is_Read_Only__c, Is_Always_Required__c, Reference_To__c, Section_Label__c,
                Display_Order__c, Default_Visibility__c,
                Is_Required_Layout__c, Regex_Pattern__c,
                Regex_Error_Message__c, Is_Active__c,
                (SELECT Stage_Value__c, Visibility__c FROM Field_Stage_Configs__r),
                (SELECT Picklist_Value__c, Custom_Permission_API_Name__c FROM Picklist_Permission_Mappings__r)
            FROM Custom_Field_Mapping__c
            WHERE Object_Mapping__c = :objectMappingId
            ORDER BY Display_Order__c ASC NULLS LAST
        ]) {
            FormWrappers.FieldConfigWrapper fw = new FormWrappers.FieldConfigWrapper();
            fw.fieldApiName = fm.Field_API_Name__c;
            fw.labelOverride = fm.Field_Label_Override__c;
            fw.fieldType = fm.Field_Type__c;
            fw.fieldSubtype = fm.Field_Subtype__c;
            fw.addressGroup = fm.Address_Group__c;
            fw.isReadOnly = fm.Is_Read_Only__c;
            fw.isAlwaysRequired = fm.Is_Always_Required__c;
            fw.referenceTo = fm.Reference_To__c;
            fw.sectionLabel = fm.Section_Label__c;
            fw.displayOrder = fm.Display_Order__c != null ? Integer.valueOf(fm.Display_Order__c) : null;
            fw.defaultVisibility = fm.Default_Visibility__c;
            fw.isRequiredLayout = fm.Is_Required_Layout__c;
            fw.regexPattern = fm.Regex_Pattern__c;
            fw.regexErrorMessage = fm.Regex_Error_Message__c;

            fw.stageConfigs = new List<FormWrappers.StageConfigWrapper>();
            if (fm.Field_Stage_Configs__r != null) {
                for (Field_Stage_Config__c sc : fm.Field_Stage_Configs__r) {
                    FormWrappers.StageConfigWrapper sw = new FormWrappers.StageConfigWrapper();
                    sw.stageValue = sc.Stage_Value__c;
                    sw.visibility = sc.Visibility__c;
                    fw.stageConfigs.add(sw);
                }
            }

            fw.picklistPermissions = new List<FormWrappers.PicklistPermissionWrapper>();
            if (fm.Picklist_Permission_Mappings__r != null) {
                for (Picklist_Permission_Mapping__c pp : fm.Picklist_Permission_Mappings__r) {
                    FormWrappers.PicklistPermissionWrapper pw = new FormWrappers.PicklistPermissionWrapper();
                    pw.picklistValue = pp.Picklist_Value__c;
                    pw.customPermissionApiName = pp.Custom_Permission_API_Name__c;
                    fw.picklistPermissions.add(pw);
                }
            }

            result.add(fw);
        }

        return result;
    }

    @AuraEnabled
    public static void saveFieldMappings(String objectMappingId, String fieldMappingsJson) {
        List<Object> rawList = (List<Object>) JSON.deserializeUntyped(fieldMappingsJson);

        List<Custom_Field_Mapping__c> existing = [
            SELECT Id, Field_API_Name__c FROM Custom_Field_Mapping__c
            WHERE Object_Mapping__c = :objectMappingId
        ];
        Map<String, Id> existingByApiName = new Map<String, Id>();
        for (Custom_Field_Mapping__c cfm : existing) {
            existingByApiName.put(cfm.Field_API_Name__c, cfm.Id);
        }

        List<Custom_Field_Mapping__c> toUpsert = new List<Custom_Field_Mapping__c>();
        Set<String> incomingApiNames = new Set<String>();

        for (Object item : rawList) {
            Map<String, Object> fm = (Map<String, Object>) item;
            String apiName = (String) fm.get('fieldApiName');
            incomingApiNames.add(apiName);

            Custom_Field_Mapping__c cfm = new Custom_Field_Mapping__c();
            if (existingByApiName.containsKey(apiName)) {
                cfm.Id = existingByApiName.get(apiName);
            } else {
                cfm.Object_Mapping__c = objectMappingId;
                cfm.Field_API_Name__c = apiName;
            }

            if (fm.get('labelOverride') != null) cfm.Field_Label_Override__c = (String) fm.get('labelOverride');
            if (fm.get('fieldType') != null) cfm.Field_Type__c = (String) fm.get('fieldType');
            if (fm.get('fieldSubtype') != null) cfm.Field_Subtype__c = (String) fm.get('fieldSubtype');
            if (fm.get('addressGroup') != null) cfm.Address_Group__c = (String) fm.get('addressGroup');
            if (fm.get('isReadOnly') != null) cfm.Is_Read_Only__c = Boolean.valueOf(String.valueOf(fm.get('isReadOnly')));
            if (fm.get('referenceTo') != null) cfm.Reference_To__c = (String) fm.get('referenceTo');
            if (fm.get('sectionLabel') != null) cfm.Section_Label__c = (String) fm.get('sectionLabel');
            if (fm.get('displayOrder') != null) cfm.Display_Order__c = Decimal.valueOf(String.valueOf(fm.get('displayOrder')));
            if (fm.get('defaultVisibility') != null) cfm.Default_Visibility__c = (String) fm.get('defaultVisibility');
            if (fm.get('isRequiredLayout') != null) cfm.Is_Required_Layout__c = Boolean.valueOf(String.valueOf(fm.get('isRequiredLayout')));
            if (fm.get('regexPattern') != null) cfm.Regex_Pattern__c = (String) fm.get('regexPattern');
            if (fm.get('regexErrorMessage') != null) cfm.Regex_Error_Message__c = (String) fm.get('regexErrorMessage');
            if (fm.get('isActive') != null) cfm.Is_Active__c = Boolean.valueOf(String.valueOf(fm.get('isActive')));

            toUpsert.add(cfm);
        }

        if (!toUpsert.isEmpty()) upsert toUpsert;
    }

    @AuraEnabled(cacheable=true)
    public static List<FormWrappers.PicklistValueWrapper> getPicklistValues(String objectApiName, String fieldApiName) {
        List<FormWrappers.PicklistValueWrapper> result = new List<FormWrappers.PicklistValueWrapper>();

        Schema.SObjectField sof = Schema.getGlobalDescribe()
            .get(objectApiName)?.getDescribe().fields.getMap().get(fieldApiName.toLowerCase());
        if (sof == null) return result;

        for (Schema.PicklistEntry entry : sof.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) continue;
            FormWrappers.PicklistValueWrapper pw = new FormWrappers.PicklistValueWrapper();
            pw.value = entry.getValue();
            pw.label = entry.getLabel();
            pw.isDefault = entry.isDefaultValue();
            result.add(pw);
        }

        return result;
    }
}
