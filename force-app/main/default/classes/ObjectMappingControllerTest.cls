@IsTest
class ObjectMappingControllerTest {

    class SuccessMock implements HttpCalloutMock {
        private String body;
        SuccessMock(String body) { this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(body);
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

    @IsTest
    static void testGetObjects() {
        String body = '{"records":[{"QualifiedApiName":"Account","Label":"Account"},{"QualifiedApiName":"Contact","Label":"Contact"}]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(body));
        Test.startTest();
        List<FormWrappers.ObjectWrapper> result = ObjectMappingController.getObjects();
        Test.stopTest();
        Assert.areEqual(2, result.size());
        Assert.areEqual('Account', result[0].apiName);
        Assert.areEqual('Account', result[0].label);
    }

    @IsTest
    static void testGetObjectsError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        try {
            ObjectMappingController.getObjects();
            Assert.fail('Expected AuraHandledException');
        } catch (Exception e) {
            Assert.isNotNull(e);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetPageLayouts() {
        String body = '{"records":[{"Id":"0AhXXX001","Name":"Account Layout"},{"Id":"0AhXXX002","Name":"Account Mini"}]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(body));
        Test.startTest();
        List<FormWrappers.LayoutWrapper> result = ObjectMappingController.getPageLayouts('Account');
        Test.stopTest();
        Assert.areEqual(2, result.size());
        Assert.areEqual('0AhXXX001', result[0].id);
        Assert.areEqual('Account Layout', result[0].name);
    }

    @IsTest
    static void testGetPageLayoutsError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        try {
            ObjectMappingController.getPageLayouts('Account');
            Assert.fail('Expected AuraHandledException');
        } catch (Exception e) {
            Assert.isNotNull(e);
        }
        Test.stopTest();
    }
}
