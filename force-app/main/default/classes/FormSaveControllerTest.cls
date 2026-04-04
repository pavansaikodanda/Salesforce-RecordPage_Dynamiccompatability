@IsTest
class FormSaveControllerTest {

    @IsTest
    static void testInsertRecord() {
        Map<String, Object> fieldData = new Map<String, Object>{ 'Name' => 'Test Account Insert' };
        Test.startTest();
        FormWrappers.SaveResultWrapper result = FormSaveController.saveRecord(
            'Account', null, JSON.serialize(fieldData)
        );
        Test.stopTest();
        Assert.isTrue(result.isSuccess);
        Assert.isNotNull(result.recordId);
        Assert.isNull(result.errorMessage);
    }

    @IsTest
    static void testUpdateRecord() {
        Account acc = new Account(Name = 'Old Name');
        insert acc;
        Map<String, Object> fieldData = new Map<String, Object>{ 'Name' => 'Updated Name' };
        Test.startTest();
        FormWrappers.SaveResultWrapper result = FormSaveController.saveRecord(
            'Account', acc.Id, JSON.serialize(fieldData)
        );
        Test.stopTest();
        Assert.isTrue(result.isSuccess);
        Assert.areEqual(acc.Id, result.recordId);
        Assert.areEqual('Updated Name', [SELECT Name FROM Account WHERE Id = :acc.Id].Name);
    }

    @IsTest
    static void testDmlError() {
        // Insert Account without Name — DML will fail
        Map<String, Object> fieldData = new Map<String, Object>();
        Test.startTest();
        FormWrappers.SaveResultWrapper result = FormSaveController.saveRecord(
            'Account', null, JSON.serialize(fieldData)
        );
        Test.stopTest();
        Assert.isFalse(result.isSuccess);
        Assert.isNotNull(result.errorMessage);
    }

    @IsTest
    static void testNumericTypeConversion() {
        Map<String, Object> fieldData = new Map<String, Object>{
            'Name' => 'Numeric Test Account',
            'NumberOfEmployees' => 250.0,
            'AnnualRevenue' => 1000000.0
        };
        Test.startTest();
        FormWrappers.SaveResultWrapper result = FormSaveController.saveRecord(
            'Account', null, JSON.serialize(fieldData)
        );
        Test.stopTest();
        Assert.isTrue(result.isSuccess);
        Account acc = [SELECT NumberOfEmployees, AnnualRevenue FROM Account WHERE Id = :result.recordId];
        Assert.areEqual(250, acc.NumberOfEmployees);
        Assert.areEqual(1000000, acc.AnnualRevenue);
    }

    @IsTest
    static void testBooleanTypeConversion() {
        // Use Contact — HasOptedOutOfEmail is a boolean field
        Contact c = new Contact(LastName = 'BoolTest');
        insert c;
        Map<String, Object> fieldData = new Map<String, Object>{
            'LastName' => 'BoolUpdated',
            'HasOptedOutOfEmail' => true
        };
        Test.startTest();
        FormWrappers.SaveResultWrapper result = FormSaveController.saveRecord(
            'Contact', c.Id, JSON.serialize(fieldData)
        );
        Test.stopTest();
        Assert.isTrue(result.isSuccess);
        Assert.isTrue([SELECT HasOptedOutOfEmail FROM Contact WHERE Id = :c.Id].HasOptedOutOfEmail);
    }

    @IsTest
    static void testNullFieldsSkipped() {
        Map<String, Object> fieldData = new Map<String, Object>{
            'Name' => 'Null Skip Test',
            'Industry' => null
        };
        Test.startTest();
        FormWrappers.SaveResultWrapper result = FormSaveController.saveRecord(
            'Account', null, JSON.serialize(fieldData)
        );
        Test.stopTest();
        Assert.isTrue(result.isSuccess);
    }
}
