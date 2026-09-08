/**
 * @description fflib Selector for User, registered in hfs_Application.Selector.
 * Runs in SYSTEM_MODE: called only from the elevated (guest) self-registration
 * provisioning flow, where the Guest User has no read access to User / Profile.
 * Exposure stays constrained by the fixed field list and injection-safe binds.
 */
public inherited sharing class hfs_UsersSelector extends fflib_SObjectSelector {
    /**
     * @description The SObject this selector queries.
     * @return User.SObjectType
     */
    public Schema.SObjectType getSObjectType() {
        return User.SObjectType;
    }

    /**
     * @description The default field list selected by this selector.
     * @return the User fields
     */
    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{ User.Id, User.Username, User.Email };
    }

    /**
     * @description Generic, injection-safe query over User, for callers that need
     * an arbitrary field list / WHERE clause rather than the fixed selector fields.
     * @param whereClause SOQL WHERE body (no leading WHERE), using named binds
     * @param bindMap bind variable map
     * @param fieldsToGet fields to select
     * @return matching User records
     */
    public List<User> getUsersRecords(String whereClause, Map<String, Object> bindMap, List<String> fieldsToGet) {
        String soql = 'SELECT ' + String.join(fieldsToGet, ', ') + ' FROM User';
        if (String.isNotBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }
        return Database.queryWithBinds(soql, bindMap, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Resolves a Profile Id by name in system mode (guest context).
     * @param profileName the profile name
     * @return the Profile Id, or null when not found
     */
    public Id getProfileIdByName(String profileName) {
        List<Profile> profiles = [
            SELECT Id FROM Profile WHERE Name = :profileName WITH SYSTEM_MODE LIMIT 1
        ];
        return profiles.isEmpty() ? null : profiles[0].Id;
    }

    /**
     * @description Resolves the active internal owner for the portal Account by
     * username in system mode (guest context), including its UserRoleId. The
     * caller validates the role: Salesforce requires the owner of a portal
     * (community) account to hold a UserRole before a portal User can be created
     * under it.
     * @param username the User.Username to resolve
     * @return the matching active User (Id + UserRoleId), or null when not found
     */
    public User getPortalAccountOwner(String username) {
        if (String.isBlank(username)) {
            return null;
        }
        List<User> owners = [
            SELECT Id, UserRoleId FROM User
            WHERE Username = :username AND IsActive = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return owners.isEmpty() ? null : owners[0];
    }
}