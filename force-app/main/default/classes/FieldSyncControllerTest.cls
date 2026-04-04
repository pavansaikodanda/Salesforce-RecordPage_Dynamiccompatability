@IsTest
class FieldSyncControllerTest {

    static final String LAYOUT_MOCK_BODY = '{"Metadata":{"layoutSections":['
        + '{"label":"Information","layoutColumns":['
        + '{"layoutItems":['
        + '{"field":"Name","required":false,"behavior":"Edit"},'
        + '{"field":"Industry","required":false,"behavior":"Edit"}'
        + ']},'
        + '{"layoutItems":['
        + '{"field":null,"emptySpace":true}'
        + ']}'
        + ']}'
        + ']}}';

    class LayoutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(LAYOUT_MOCK_BODY);
            return res;
        }
    }

    class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            return res;
        }
    }

    static Custom_Object_Mapping__c insertMapping() {
        Custom_Object_Mapping__c m = new Custom_Object_Mapping__c(
            Name = 'Test Mapping',
            Developer_Name__c = 'Test_Sync_Mapping',
            Object_API_Name__c = 'Account',
            Page_Layout_ID__c = '0AhXXXXXXXXXXX'
        );
        insert m;
        return m;
    }

    @IsTest
    static void testSyncAddsNewFields() {
        Custom_Object_Mapping__c m = insertMapping();
        Test.setMock(HttpCalloutMock.class, new LayoutMock());
        Test.startTest();
        FormWrappers.SyncResultWrapper result = FieldSyncController.syncFields(m.Id);
        Test.stopTest();
        Assert.areEqual(2, result.added);
        Assert.areEqual(0, result.removed);
        Assert.areEqual(0, result.unchanged);
        Assert.areEqual(2, [SELECT COUNT() FROM Custom_Field_Mapping__c WHERE Object_Mapping__c = :m.Id]);
    }

    @IsTest
    static void testSyncRemovesOldFields() {
        Custom_Object_Mapping__c m = insertMapping();
        insert new Custom_Field_Mapping__c(
            Object_Mapping__c = m.Id,
            Field_API_Name__c = 'OldField__c'
        );
        Test.setMock(HttpCalloutMock.class, new LayoutMock());
        Test.startTest();
        FormWrappers.SyncResultWrapper result = FieldSyncController.syncFields(m.Id);
        Test.stopTest();
        Assert.areEqual(2, result.added);
        Assert.areEqual(1, result.removed);
        Assert.areEqual(0, result.unchanged);
    }

    @IsTest
    static void testSyncUnchangedFields() {
        Custom_Object_Mapping__c m = insertMapping();
        insert new Custom_Field_Mapping__c(
            Object_Mapping__c = m.Id,
            Field_API_Name__c = 'Name'
        );
        Test.setMock(HttpCalloutMock.class, new LayoutMock());
        Test.startTest();
        FormWrappers.SyncResultWrapper result = FieldSyncController.syncFields(m.Id);
        Test.stopTest();
        Assert.areEqual(1, result.added);
        Assert.areEqual(0, result.removed);
        Assert.areEqual(1, result.unchanged);
    }

    @IsTest
    static void testSyncError() {
        Custom_Object_Mapping__c m = insertMapping();
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        try {
            FieldSyncController.syncFields(m.Id);
            Assert.fail('Expected exception');
        } catch (Exception e) {
            Assert.isNotNull(e);
        }
        Test.stopTest();
    }
}
