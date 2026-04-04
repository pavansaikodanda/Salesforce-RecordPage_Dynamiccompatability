@IsTest
class CustomPermissionHelperTest {

    @IsTest
    static void testGetPermissionsForUser() {
        Test.startTest();
        Set<String> perms = CustomPermissionHelper.getPermissionsForUser();
        Test.stopTest();
        Assert.isNotNull(perms);
    }
}
