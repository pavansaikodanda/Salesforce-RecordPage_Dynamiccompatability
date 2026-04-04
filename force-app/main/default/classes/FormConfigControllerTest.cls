@IsTest
class FormConfigControllerTest {

    @TestSetup
    static void setup() {
        Custom_Object_Mapping__c mapping = new Custom_Object_Mapping__c(
            Name = 'Test Account Form',
            Developer_Name__c = 'Test_Account_Form',
            Object_API_Name__c = 'Account',
            Page_Layout_ID__c = '0AhXXXXXXXXXXX',
            Is_Active__c = true,
            Enforce_Path_Order__c = false,
            Stage_Order_Source__c = 'Custom Order'
        );
        insert mapping;

        Custom_Field_Mapping__c fm = new Custom_Field_Mapping__c(
            Object_Mapping__c = mapping.Id,
            Field_API_Name__c = 'Name',
            Field_Type__c = 'String',
            Default_Visibility__c = 'Visible',
            Is_Active__c = true,
            Display_Order__c = 1
        );
        insert fm;

        insert new Field_Stage_Config__c(
            Field_Mapping__c = fm.Id,
            Stage_Value__c = 'Prospecting',
            Visibility__c = 'Visible'
        );

        insert new Picklist_Permission_Mapping__c(
            Field_Mapping__c = fm.Id,
            Picklist_Value__c = 'TestVal',
            Custom_Permission_API_Name__c = 'TestPermission'
        );

        Custom_Path_Mapping__c pm = new Custom_Path_Mapping__c(
            Object_Mapping__c = mapping.Id,
            Stage_Value__c = 'Prospecting',
            Stage_Label__c = 'Prospecting',
            Stage_Order__c = 1,
            Is_Active__c = true,
            Guidance_Text__c = 'Start here'
        );
        insert pm;

        insert new Custom_Path_Transition__c(
            Path_Mapping__c = pm.Id,
            From_Stage__c = 'Prospecting',
            To_Stage__c = 'Qualification',
            Is_Allowed__c = true
        );
    }

    @IsTest
    static void testGetFormConfigNoRecord() {
        Test.startTest();
        FormWrappers.FormConfigWrapper config = FormConfigController.getFormConfig('Test_Account_Form', null);
        Test.stopTest();
        Assert.areEqual('Account', config.objectApiName);
        Assert.areEqual(1, config.fields.size());
        Assert.areEqual('Name', config.fields[0].fieldApiName);
        Assert.areEqual(1, config.fields[0].stageConfigs.size());
        Assert.areEqual(1, config.fields[0].picklistPermissions.size());
        Assert.isNotNull(config.pathConfig);
        Assert.areEqual(1, config.pathConfig.stages.size());
        Assert.areEqual(1, config.pathConfig.transitions.size());
        Assert.isNotNull(config.userPermissions);
    }

    @IsTest
    static void testGetFormConfigWithRecord() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Test.startTest();
        FormWrappers.FormConfigWrapper config = FormConfigController.getFormConfig('Test_Account_Form', acc.Id);
        Test.stopTest();
        Assert.areEqual('Account', config.objectApiName);
        Assert.isNotNull(config.currentRecordData);
        Assert.isFalse(config.currentRecordData.isEmpty());
    }

    @IsTest
    static void testGetFormConfigNotFound() {
        Test.startTest();
        try {
            FormConfigController.getFormConfig('Nonexistent_Mapping_XYZ', null);
            Assert.fail('Expected AuraHandledException');
        } catch (Exception e) {
            Assert.isNotNull(e);
        }
        Test.stopTest();
    }
}
