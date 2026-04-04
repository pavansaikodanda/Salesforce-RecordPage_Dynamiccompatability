@IsTest
class FormWrappersTest {

    @IsTest
    static void testAllWrappers() {
        FormWrappers.FormConfigWrapper config = new FormWrappers.FormConfigWrapper();
        config.objectApiName = 'Account';
        config.currentStageValue = 'Open';
        config.currentRecordData = new Map<String, Object>{ 'Name' => 'Test' };
        config.userPermissions = new List<String>{ 'MyPermission' };
        config.fields = new List<FormWrappers.FieldConfigWrapper>();
        config.pathConfig = new FormWrappers.PathConfigWrapper();

        Assert.areEqual('Account', config.objectApiName);
        Assert.areEqual('Open', config.currentStageValue);
        Assert.areEqual(1, config.userPermissions.size());

        FormWrappers.FieldConfigWrapper field = new FormWrappers.FieldConfigWrapper();
        field.fieldApiName = 'Name';
        field.labelOverride = 'Full Name';
        field.fieldType = 'String';
        field.referenceTo = null;
        field.sectionLabel = 'Info';
        field.displayOrder = 1;
        field.defaultVisibility = 'Visible';
        field.isRequiredLayout = false;
        field.regexPattern = '[A-Z]+';
        field.regexErrorMessage = 'Letters only';
        field.defaultValue = 'DefaultVal';
        field.stageConfigs = new List<FormWrappers.StageConfigWrapper>();
        field.picklistPermissions = new List<FormWrappers.PicklistPermissionWrapper>();
        config.fields.add(field);

        Assert.areEqual('Name', field.fieldApiName);
        Assert.areEqual(1, field.displayOrder);

        FormWrappers.StageConfigWrapper stage = new FormWrappers.StageConfigWrapper();
        stage.stageValue = 'Prospecting';
        stage.visibility = 'Visible';
        Assert.areEqual('Prospecting', stage.stageValue);

        FormWrappers.PicklistPermissionWrapper pp = new FormWrappers.PicklistPermissionWrapper();
        pp.picklistValue = 'Val1';
        pp.customPermissionApiName = 'Perm1';
        Assert.areEqual('Val1', pp.picklistValue);

        FormWrappers.PathConfigWrapper pathConfig = new FormWrappers.PathConfigWrapper();
        pathConfig.enforceOrder = true;
        pathConfig.stageOrderSource = 'Custom Order';
        pathConfig.stages = new List<FormWrappers.PathStageWrapper>();
        pathConfig.transitions = new List<FormWrappers.PathTransitionWrapper>();
        Assert.isTrue(pathConfig.enforceOrder);

        FormWrappers.PathStageWrapper pathStage = new FormWrappers.PathStageWrapper();
        pathStage.stageValue = 'Prospecting';
        pathStage.stageLabel = 'Prospecting';
        pathStage.stageOrder = 1;
        pathStage.guidanceText = 'Do this first';
        Assert.areEqual(1, pathStage.stageOrder);

        FormWrappers.PathTransitionWrapper transition = new FormWrappers.PathTransitionWrapper();
        transition.fromStage = 'Prospecting';
        transition.toStage = 'Qualification';
        transition.isAllowed = true;
        Assert.isTrue(transition.isAllowed);

        FormWrappers.SyncResultWrapper sync = new FormWrappers.SyncResultWrapper();
        sync.added = 3;
        sync.removed = 1;
        sync.unchanged = 5;
        Assert.areEqual(3, sync.added);

        FormWrappers.SaveResultWrapper save = new FormWrappers.SaveResultWrapper();
        save.recordId = 'ABC123';
        save.isSuccess = true;
        save.errorMessage = null;
        Assert.isTrue(save.isSuccess);

        FormWrappers.ObjectWrapper obj = new FormWrappers.ObjectWrapper();
        obj.label = 'Account';
        obj.apiName = 'Account';
        Assert.areEqual('Account', obj.apiName);

        FormWrappers.LayoutWrapper layout = new FormWrappers.LayoutWrapper();
        layout.id = '0AhXXX';
        layout.name = 'Account Layout';
        Assert.areEqual('Account Layout', layout.name);
    }
}
