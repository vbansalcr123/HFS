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
     * @description Selects Users by username or email in system mode, for duplicate
     * detection inside the elevated guest provisioning flow.
     * @param username the username to match
     * @param email the email to match
     * @return matching Users
     */
    public List<User> selectByUsernameOrEmail(String username, String email) {
        fflib_QueryFactory qf = newQueryFactory();
        qf.setCondition('Username = :username OR Email = :email');
        return (List<User>) Database.queryWithBinds(
            qf.toSOQL(),
            new Map<String, Object>{ 'username' => username, 'email' => email },
            AccessLevel.SYSTEM_MODE
        );
    }

    /**
     * @description Resolves a Profile Id by name in system mode (guest context).
     * @param profileName the profile name
     * @return the Profile Id, or null when not found
     */
    public Id selectProfileIdByName(String profileName) {
        List<Profile> profiles = [
            SELECT Id FROM Profile WHERE Name = :profileName WITH SYSTEM_MODE LIMIT 1
        ];
        return profiles.isEmpty() ? null : profiles[0].Id;
    }

    /**
     * @description Resolves an active User Id by username in system mode (guest
     * context). Used to look up the internal role-bearing owner for the portal
     * Account so portal User creation succeeds.
     * @param username the User.Username to resolve
     * @return the User Id, or null when not found
     */
    public Id selectActiveIdByUsername(String username) {
        if (String.isBlank(username)) {
            return null;
        }
        List<User> owners = [
            SELECT Id FROM User
            WHERE Username = :username AND IsActive = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return owners.isEmpty() ? null : owners[0].Id;
    }
}
