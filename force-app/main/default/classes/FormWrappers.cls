public class FormWrappers {

    public class FormConfigWrapper {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String currentStageValue;
        @AuraEnabled public Map<String, Object> currentRecordData;
        @AuraEnabled public List<String> userPermissions;
        @AuraEnabled public List<FieldConfigWrapper> fields;
        @AuraEnabled public PathConfigWrapper pathConfig;
    }

    public class FieldConfigWrapper {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String labelOverride;
        @AuraEnabled public String fieldType;
        @AuraEnabled public String fieldSubtype;
        @AuraEnabled public String addressGroup;
        @AuraEnabled public Boolean isReadOnly;
        @AuraEnabled public String referenceTo;
        @AuraEnabled public String sectionLabel;
        @AuraEnabled public Integer displayOrder;
        @AuraEnabled public String defaultVisibility;
        @AuraEnabled public Boolean isRequiredLayout;
        @AuraEnabled public String regexPattern;
        @AuraEnabled public String regexErrorMessage;
        @AuraEnabled public Object defaultValue;
        @AuraEnabled public Boolean isAlwaysRequired;
        @AuraEnabled public List<FormWrappers.PicklistValueWrapper> picklistValues;
        @AuraEnabled public List<StageConfigWrapper> stageConfigs;
        @AuraEnabled public List<PicklistPermissionWrapper> picklistPermissions;
    }

    public class StageConfigWrapper {
        @AuraEnabled public String stageValue;
        @AuraEnabled public String visibility;
    }

    public class PicklistPermissionWrapper {
        @AuraEnabled public String picklistValue;
        @AuraEnabled public String customPermissionApiName;
    }

    public class PathConfigWrapper {
        @AuraEnabled public Boolean enforceOrder;
        @AuraEnabled public String stageOrderSource;
        @AuraEnabled public List<PathStageWrapper> stages;
        @AuraEnabled public List<PathTransitionWrapper> transitions;
    }

    public class PathStageWrapper {
        @AuraEnabled public String stageValue;
        @AuraEnabled public String stageLabel;
        @AuraEnabled public Integer stageOrder;
        @AuraEnabled public String guidanceText;
    }

    public class PathTransitionWrapper {
        @AuraEnabled public String fromStage;
        @AuraEnabled public String toStage;
        @AuraEnabled public Boolean isAllowed;
    }

    public class SyncResultWrapper {
        @AuraEnabled public Integer added;
        @AuraEnabled public Integer removed;
        @AuraEnabled public Integer unchanged;
    }

    public class SaveResultWrapper {
        @AuraEnabled public String recordId;
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
    }

    public class ObjectWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
    }

    public class LayoutWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
    }

    public class PicklistValueWrapper {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isDefault;
    }
}
