/**
 * @description Selector for User. Generic query method used for username / email
 * duplicate detection. Runs in SYSTEM_MODE: called only from the elevated (guest)
 * self-registration provisioning flow, where the Guest User has no read access to
 * User / Profile. Exposure stays constrained by the fixed field list and binds.
 */
public inherited sharing class hfs_UsersSelector {
    /**
     * @description Generic, injection-safe query over User.
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
     * @description Resolves an active User Id by username in system mode (guest
     * context). Used to look up the internal role-bearing owner for the portal
     * Account so portal User creation succeeds.
     * @param username the User.Username to resolve
     * @return the User Id, or null when not found
     */
    public Id getUserIdByUsername(String username) {
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