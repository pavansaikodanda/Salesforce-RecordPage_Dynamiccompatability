public class CustomPermissionHelper {

    public static Set<String> getPermissionsForUser() {
        Set<Id> entityIds = new Set<Id>();
        for (SetupEntityAccess sea : [
            SELECT SetupEntityId
            FROM SetupEntityAccess
            WHERE SetupEntityType = 'CustomPermission'
            AND ParentId IN (
                SELECT PermissionSetId
                FROM PermissionSetAssignment
                WHERE AssigneeId = :UserInfo.getUserId()
            )
        ]) {
            entityIds.add(sea.SetupEntityId);
        }

        Set<String> permissions = new Set<String>();
        for (CustomPermission cp : [
            SELECT DeveloperName
            FROM CustomPermission
            WHERE Id IN :entityIds
        ]) {
            permissions.add(cp.DeveloperName);
        }
        return permissions;
    }
}
