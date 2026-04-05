public class PathConfigController {

    @AuraEnabled
    public static FormWrappers.PathConfigWrapper getPathConfig(String objectMappingId) {
        Custom_Object_Mapping__c mapping = [
            SELECT Enforce_Path_Order__c, Stage_Order_Source__c,
                (SELECT Id, Stage_Value__c, Stage_Label__c, Stage_Order__c,
                    Guidance_Text__c, Is_Active__c,
                    (SELECT From_Stage__c, To_Stage__c, Is_Allowed__c
                     FROM Custom_Path_Transitions__r)
                 FROM Custom_Path_Mappings__r
                 ORDER BY Stage_Order__c ASC NULLS LAST)
            FROM Custom_Object_Mapping__c
            WHERE Id = :objectMappingId
            LIMIT 1
        ];

        FormWrappers.PathConfigWrapper result = new FormWrappers.PathConfigWrapper();
        result.enforceOrder = mapping.Enforce_Path_Order__c;
        result.stageOrderSource = mapping.Stage_Order_Source__c;
        result.stages = new List<FormWrappers.PathStageWrapper>();
        result.transitions = new List<FormWrappers.PathTransitionWrapper>();

        if (mapping.Custom_Path_Mappings__r != null) {
            for (Custom_Path_Mapping__c pm : mapping.Custom_Path_Mappings__r) {
                FormWrappers.PathStageWrapper psw = new FormWrappers.PathStageWrapper();
                psw.stageValue = pm.Stage_Value__c;
                psw.stageLabel = pm.Stage_Label__c;
                psw.stageOrder = pm.Stage_Order__c != null ? Integer.valueOf(pm.Stage_Order__c) : null;
                psw.guidanceText = pm.Guidance_Text__c;
                result.stages.add(psw);

                if (pm.Custom_Path_Transitions__r != null) {
                    for (Custom_Path_Transition__c pt : pm.Custom_Path_Transitions__r) {
                        FormWrappers.PathTransitionWrapper ptw = new FormWrappers.PathTransitionWrapper();
                        ptw.fromStage = pt.From_Stage__c;
                        ptw.toStage = pt.To_Stage__c;
                        ptw.isAllowed = pt.Is_Allowed__c;
                        result.transitions.add(ptw);
                    }
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static void savePathConfig(String objectMappingId, String pathConfigJson) {
        Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(pathConfigJson);

        Boolean enforceOrder = configMap.get('enforceOrder') != null
            ? Boolean.valueOf(String.valueOf(configMap.get('enforceOrder'))) : false;
        String stageOrderSource = (String) configMap.get('stageOrderSource');

        update new Custom_Object_Mapping__c(
            Id = objectMappingId,
            Enforce_Path_Order__c = enforceOrder,
            Stage_Order_Source__c = stageOrderSource
        );

        List<Custom_Path_Mapping__c> existingStages = [
            SELECT Id, Stage_Value__c FROM Custom_Path_Mapping__c
            WHERE Object_Mapping__c = :objectMappingId
        ];
        Map<String, Id> existingByValue = new Map<String, Id>();
        for (Custom_Path_Mapping__c pm : existingStages) {
            existingByValue.put(pm.Stage_Value__c, pm.Id);
        }

        List<Object> stagesList = configMap.get('stages') != null
            ? (List<Object>) configMap.get('stages') : new List<Object>();

        Set<String> incomingStageValues = new Set<String>();
        List<Custom_Path_Mapping__c> stagesToUpsert = new List<Custom_Path_Mapping__c>();

        for (Object stageObj : stagesList) {
            Map<String, Object> stage = (Map<String, Object>) stageObj;
            String stageValue = (String) stage.get('stageValue');
            incomingStageValues.add(stageValue);

            Custom_Path_Mapping__c pm = new Custom_Path_Mapping__c();
            if (existingByValue.containsKey(stageValue)) {
                pm.Id = existingByValue.get(stageValue);
            } else {
                pm.Object_Mapping__c = objectMappingId;
                pm.Stage_Value__c = stageValue;
            }
            String stageLabel = (String) stage.get('stageLabel');
            pm.Stage_Label__c = String.isNotBlank(stageLabel) ? stageLabel : stageValue;
            if (stage.get('stageOrder') != null) pm.Stage_Order__c = Decimal.valueOf(String.valueOf(stage.get('stageOrder')));
            if (stage.get('guidanceText') != null) pm.Guidance_Text__c = (String) stage.get('guidanceText');
            pm.Is_Active__c = true;
            stagesToUpsert.add(pm);
        }

        List<Custom_Path_Mapping__c> stagesToDelete = new List<Custom_Path_Mapping__c>();
        for (Custom_Path_Mapping__c pm : existingStages) {
            if (!incomingStageValues.contains(pm.Stage_Value__c)) {
                stagesToDelete.add(pm);
            }
        }

        if (!stagesToUpsert.isEmpty()) upsert stagesToUpsert;
        if (!stagesToDelete.isEmpty()) delete stagesToDelete;

        // Rebuild transitions: query refreshed stage map, then upsert transitions
        Map<String, Id> refreshedStageMap = new Map<String, Id>();
        for (Custom_Path_Mapping__c pm : [
            SELECT Id, Stage_Value__c FROM Custom_Path_Mapping__c
            WHERE Object_Mapping__c = :objectMappingId
        ]) {
            refreshedStageMap.put(pm.Stage_Value__c, pm.Id);
        }

        List<Custom_Path_Transition__c> existingTransitions = [
            SELECT Id, From_Stage__c, To_Stage__c
            FROM Custom_Path_Transition__c
            WHERE Path_Mapping__c IN :refreshedStageMap.values()
        ];
        Map<String, Id> existingTransitionMap = new Map<String, Id>();
        for (Custom_Path_Transition__c pt : existingTransitions) {
            existingTransitionMap.put(pt.From_Stage__c + '|' + pt.To_Stage__c, pt.Id);
        }

        List<Object> transitionsList = configMap.get('transitions') != null
            ? (List<Object>) configMap.get('transitions') : new List<Object>();

        Set<String> incomingTransitionKeys = new Set<String>();
        List<Custom_Path_Transition__c> transitionsToUpsert = new List<Custom_Path_Transition__c>();

        for (Object transObj : transitionsList) {
            Map<String, Object> trans = (Map<String, Object>) transObj;
            String fromStage = (String) trans.get('fromStage');
            String toStage = (String) trans.get('toStage');
            String key = fromStage + '|' + toStage;
            incomingTransitionKeys.add(key);

            if (!refreshedStageMap.containsKey(fromStage)) continue;

            Custom_Path_Transition__c pt = new Custom_Path_Transition__c();
            if (existingTransitionMap.containsKey(key)) {
                pt.Id = existingTransitionMap.get(key);
            } else {
                pt.Path_Mapping__c = refreshedStageMap.get(fromStage);
                pt.From_Stage__c = fromStage;
                pt.To_Stage__c = toStage;
            }
            pt.Is_Allowed__c = trans.get('isAllowed') != null
                ? Boolean.valueOf(String.valueOf(trans.get('isAllowed'))) : true;
            transitionsToUpsert.add(pt);
        }

        List<Custom_Path_Transition__c> transitionsToDelete = new List<Custom_Path_Transition__c>();
        for (Custom_Path_Transition__c pt : existingTransitions) {
            if (!incomingTransitionKeys.contains(pt.From_Stage__c + '|' + pt.To_Stage__c)) {
                transitionsToDelete.add(pt);
            }
        }

        if (!transitionsToUpsert.isEmpty()) upsert transitionsToUpsert;
        if (!transitionsToDelete.isEmpty()) delete transitionsToDelete;
    }
}
