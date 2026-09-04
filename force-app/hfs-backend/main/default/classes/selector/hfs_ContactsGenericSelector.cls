/**
 * @description Selector for Contact. One generic query method; the Service layer
 * builds the whereClause and bind map. Runs in SYSTEM_MODE: the only caller is
 * duplicate detection inside the elevated (guest) self-registration provisioning
 * flow, where the running Guest User has no read access to Contact. Object
 * exposure stays constrained by the fixed field list and injection-safe binds.
 */
public inherited sharing class hfs_ContactsGenericSelector {
    /**
     * @description Generic, injection-safe query over Contact.
     * @param whereClause SOQL WHERE body (no leading WHERE), using named binds
     * @param bindMap bind variable map, never string-concatenated values
     * @param fieldsToGet fields to select
     * @return matching Contact records
     */
    public List<Contact> getContactsRecords(String whereClause, Map<String, Object> bindMap, List<String> fieldsToGet) {
        String soql = 'SELECT ' + String.join(fieldsToGet, ', ') + ' FROM Contact';
        if (String.isNotBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }
        return Database.queryWithBinds(soql, bindMap, AccessLevel.SYSTEM_MODE);
    }
}