public class FormConfigController {

    @AuraEnabled
    public static FormWrappers.FormConfigWrapper getFormConfig(String developerName, String recordId) {
        List<Custom_Object_Mapping__c> mappings = [
            SELECT Id, Object_API_Name__c, Stage_Picklist_Field__c,
                Enforce_Path_Order__c, Stage_Order_Source__c,
                (SELECT Id, Field_API_Name__c, Field_Label_Override__c,
                    Field_Type__c, Reference_To__c, Section_Label__c,
                    Display_Order__c, Default_Visibility__c,
                    Is_Required_Layout__c, Regex_Pattern__c,
                    Regex_Error_Message__c, Is_Active__c,
                    (SELECT Stage_Value__c, Visibility__c
                     FROM Field_Stage_Configs__r),
                    (SELECT Picklist_Value__c, Custom_Permission_API_Name__c
                     FROM Picklist_Permission_Mappings__r)
                 FROM Custom_Field_Mappings__r
                 WHERE Is_Active__c = true
                 ORDER BY Display_Order__c ASC NULLS LAST),
                (SELECT Stage_Value__c, Stage_Label__c, Stage_Order__c,
                    Guidance_Text__c, Is_Active__c,
                    (SELECT From_Stage__c, To_Stage__c, Is_Allowed__c
                     FROM Custom_Path_Transitions__r)
                 FROM Custom_Path_Mappings__r
                 WHERE Is_Active__c = true
                 ORDER BY Stage_Order__c ASC NULLS LAST)
            FROM Custom_Object_Mapping__c
            WHERE Developer_Name__c = :developerName
            LIMIT 1
        ];

        if (mappings.isEmpty()) {
            throw new AuraHandledException('No mapping found for: ' + developerName);
        }

        Custom_Object_Mapping__c mapping = mappings[0];
        String objectApiName = mapping.Object_API_Name__c;

        Map<String, Schema.SObjectField> schemaFields = Schema.getGlobalDescribe()
            .get(objectApiName)?.getDescribe().fields.getMap();

        Set<String> userPerms = CustomPermissionHelper.getPermissionsForUser();

        FormWrappers.FormConfigWrapper config = new FormWrappers.FormConfigWrapper();
        config.objectApiName = objectApiName;
        config.userPermissions = new List<String>(userPerms);
        config.fields = new List<FormWrappers.FieldConfigWrapper>();

        List<Custom_Field_Mapping__c> fieldMappings = mapping.Custom_Field_Mappings__r != null
            ? mapping.Custom_Field_Mappings__r
            : new List<Custom_Field_Mapping__c>();

        // Fetch current record data if recordId provided
        Map<String, Object> recordData = new Map<String, Object>();
        if (String.isNotBlank(recordId) && !fieldMappings.isEmpty()) {
            List<String> fieldApiNames = new List<String>{ 'Id' };
            if (String.isNotBlank(mapping.Stage_Picklist_Field__c)) {
                fieldApiNames.add(mapping.Stage_Picklist_Field__c);
            }
            for (Custom_Field_Mapping__c fm : fieldMappings) {
                fieldApiNames.add(fm.Field_API_Name__c);
            }
            String soql = 'SELECT ' + String.join(fieldApiNames, ', ')
                + ' FROM ' + objectApiName
                + ' WHERE Id = :recordId LIMIT 1';
            List<SObject> records = Database.query(soql);
            if (!records.isEmpty()) {
                recordData = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(records[0]));
                if (String.isNotBlank(mapping.Stage_Picklist_Field__c)) {
                    config.currentStageValue = (String) recordData.get(mapping.Stage_Picklist_Field__c);
                }
            }
        }
        config.currentRecordData = recordData;

        // Map field mappings to wrappers
        for (Custom_Field_Mapping__c fm : fieldMappings) {
            FormWrappers.FieldConfigWrapper fw = new FormWrappers.FieldConfigWrapper();
            fw.fieldApiName = fm.Field_API_Name__c;
            fw.labelOverride = fm.Field_Label_Override__c;
            fw.fieldType = fm.Field_Type__c;
            fw.referenceTo = fm.Reference_To__c;
            fw.sectionLabel = fm.Section_Label__c;
            fw.displayOrder = fm.Display_Order__c != null ? Integer.valueOf(fm.Display_Order__c) : null;
            fw.defaultVisibility = fm.Default_Visibility__c;
            fw.isRequiredLayout = fm.Is_Required_Layout__c;
            fw.regexPattern = fm.Regex_Pattern__c;
            fw.regexErrorMessage = fm.Regex_Error_Message__c;

            if (schemaFields != null) {
                Schema.SObjectField sof = schemaFields.get(fm.Field_API_Name__c.toLowerCase());
                if (sof != null) {
                    fw.defaultValue = sof.getDescribe().getDefaultValue();
                }
            }

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

            config.fields.add(fw);
        }

        // Map path config
        List<Custom_Path_Mapping__c> pathMappings = mapping.Custom_Path_Mappings__r != null
            ? mapping.Custom_Path_Mappings__r
            : new List<Custom_Path_Mapping__c>();

        if (!pathMappings.isEmpty()) {
            FormWrappers.PathConfigWrapper pathConfig = new FormWrappers.PathConfigWrapper();
            pathConfig.enforceOrder = mapping.Enforce_Path_Order__c;
            pathConfig.stageOrderSource = mapping.Stage_Order_Source__c;
            pathConfig.stages = new List<FormWrappers.PathStageWrapper>();
            pathConfig.transitions = new List<FormWrappers.PathTransitionWrapper>();

            for (Custom_Path_Mapping__c pm : pathMappings) {
                FormWrappers.PathStageWrapper psw = new FormWrappers.PathStageWrapper();
                psw.stageValue = pm.Stage_Value__c;
                psw.stageLabel = pm.Stage_Label__c;
                psw.stageOrder = pm.Stage_Order__c != null ? Integer.valueOf(pm.Stage_Order__c) : null;
                psw.guidanceText = pm.Guidance_Text__c;
                pathConfig.stages.add(psw);

                if (pm.Custom_Path_Transitions__r != null) {
                    for (Custom_Path_Transition__c pt : pm.Custom_Path_Transitions__r) {
                        FormWrappers.PathTransitionWrapper ptw = new FormWrappers.PathTransitionWrapper();
                        ptw.fromStage = pt.From_Stage__c;
                        ptw.toStage = pt.To_Stage__c;
                        ptw.isAllowed = pt.Is_Allowed__c;
                        pathConfig.transitions.add(ptw);
                    }
                }
            }
            config.pathConfig = pathConfig;
        }

        return config;
    }
}
