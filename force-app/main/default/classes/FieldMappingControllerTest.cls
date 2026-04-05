@IsTest
class FieldMappingControllerTest {

    static Custom_Object_Mapping__c insertMapping() {
        Custom_Object_Mapping__c mapping = new Custom_Object_Mapping__c(
            Name = 'FM Test Mapping',
            Developer_Name__c = 'FM_Test_Mapping',
            Object_API_Name__c = 'Account',
            Page_Layout_ID__c = '0AhXXXXXXXXXXX'
        );
        insert mapping;
        return mapping;
    }

    static Custom_Field_Mapping__c insertFieldMapping(Id mappingId, String apiName, Integer order) {
        Custom_Field_Mapping__c fm = new Custom_Field_Mapping__c(
            Object_Mapping__c = mappingId,
            Field_API_Name__c = apiName,
            Field_Type__c = 'STRING',
            Field_Subtype__c = 'Standard',
            Address_Group__c = null,
            Is_Read_Only__c = false,
            Display_Order__c = order,
            Default_Visibility__c = 'Visible',
            Is_Active__c = true
        );
        insert fm;
        return fm;
    }

    @IsTest
    static void testGetFieldMappings() {
        Custom_Object_Mapping__c mapping = insertMapping();
        Custom_Field_Mapping__c fm1 = insertFieldMapping(mapping.Id, 'Name', 1);
        Custom_Field_Mapping__c fm2 = insertFieldMapping(mapping.Id, 'Industry', 2);

        insert new Field_Stage_Config__c(
            Field_Mapping__c = fm1.Id,
            Stage_Value__c = 'Open',
            Visibility__c = 'Visible'
        );
        insert new Picklist_Permission_Mapping__c(
            Field_Mapping__c = fm1.Id,
            Picklist_Value__c = 'Technology',
            Custom_Permission_API_Name__c = 'Dynamic_UI_Access'
        );

        Test.startTest();
        List<FormWrappers.FieldConfigWrapper> results = FieldMappingController.getFieldMappings(mapping.Id);
        Test.stopTest();

        Assert.areEqual(2, results.size());
        Assert.areEqual('Name', results[0].fieldApiName);
        Assert.areEqual(1, results[0].stageConfigs.size());
        Assert.areEqual(1, results[0].picklistPermissions.size());
        Assert.areEqual('Industry', results[1].fieldApiName);
    }

    @IsTest
    static void testGetFieldMappingsEmpty() {
        Custom_Object_Mapping__c mapping = insertMapping();
        Test.startTest();
        List<FormWrappers.FieldConfigWrapper> results = FieldMappingController.getFieldMappings(mapping.Id);
        Test.stopTest();
        Assert.areEqual(0, results.size());
    }

    @IsTest
    static void testSaveFieldMappingsInsert() {
        Custom_Object_Mapping__c mapping = insertMapping();

        List<Map<String, Object>> fmList = new List<Map<String, Object>>{
            new Map<String, Object>{
                'fieldApiName' => 'Name',
                'fieldType' => 'STRING',
                'fieldSubtype' => 'Standard',
                'defaultVisibility' => 'Visible',
                'isReadOnly' => false,
                'isRequiredLayout' => true,
                'isActive' => true
            }
        };

        Test.startTest();
        FieldMappingController.saveFieldMappings(mapping.Id, JSON.serialize(fmList));
        Test.stopTest();

        List<Custom_Field_Mapping__c> saved = [SELECT Field_API_Name__c, Is_Required_Layout__c FROM Custom_Field_Mapping__c WHERE Object_Mapping__c = :mapping.Id];
        Assert.areEqual(1, saved.size());
        Assert.areEqual('Name', saved[0].Field_API_Name__c);
        Assert.isTrue(saved[0].Is_Required_Layout__c);
    }

    @IsTest
    static void testSaveFieldMappingsUpdate() {
        Custom_Object_Mapping__c mapping = insertMapping();
        insertFieldMapping(mapping.Id, 'Industry', 1);

        List<Map<String, Object>> fmList = new List<Map<String, Object>>{
            new Map<String, Object>{
                'fieldApiName' => 'Industry',
                'labelOverride' => 'Sector',
                'isActive' => true
            }
        };

        Test.startTest();
        FieldMappingController.saveFieldMappings(mapping.Id, JSON.serialize(fmList));
        Test.stopTest();

        Custom_Field_Mapping__c updated = [SELECT Field_Label_Override__c FROM Custom_Field_Mapping__c WHERE Object_Mapping__c = :mapping.Id AND Field_API_Name__c = 'Industry'];
        Assert.areEqual('Sector', updated.Field_Label_Override__c);
    }

    @IsTest
    static void testGetPicklistValues() {
        Test.startTest();
        List<FormWrappers.PicklistValueWrapper> values = FieldMappingController.getPicklistValues('Account', 'Industry');
        Test.stopTest();
        Assert.isTrue(values.size() > 0);
        Assert.isNotNull(values[0].value);
        Assert.isNotNull(values[0].label);
        Assert.isNotNull(values[0].isDefault);
    }

    @IsTest
    static void testGetPicklistValuesInvalidField() {
        Test.startTest();
        List<FormWrappers.PicklistValueWrapper> values = FieldMappingController.getPicklistValues('Account', 'NonExistentField__c');
        Test.stopTest();
        Assert.areEqual(0, values.size());
    }
}
