/**
 * @description fflib Selector for Contact, registered in hfs_Application.Selector.
 * Centralises the Contact field list and standard id-based selection through the
 * fflib QueryFactory (enforces FLS/CRUD), plus a generic query method for
 * callers (e.g. the self-registration Service) that need an arbitrary field
 * list / WHERE clause rather than the fixed selector fields.
 */
public inherited sharing class hfs_ContactsSelector extends fflib_SObjectSelector {
    /**
     * @description The SObject this selector queries.
     * @return Contact.SObjectType
     */
    public Schema.SObjectType getSObjectType() {
        return Contact.SObjectType;
    }

    /**
     * @description The default field list selected by this selector.
     * @return the Contact fields
     */
    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Contact.Id,
            Contact.FirstName,
            Contact.LastName,
            Contact.Email,
            Contact.AccountId
        };
    }

    /**
     * @description Selects Contacts by Id using the standard field list.
     * @param idSet the Contact Ids
     * @return matching Contacts
     */
    public List<Contact> selectById(Set<Id> idSet) {
        return (List<Contact>) selectSObjectsById(idSet);
    }

    /**
     * @description Selects Contacts by email in system mode for duplicate detection
     * inside the elevated guest provisioning flow.
     * @param emails the emails to match
     * @return matching Contacts
     */
    public List<Contact> selectByEmail(Set<String> emails) {
        fflib_QueryFactory qf = newQueryFactory();
        qf.setCondition('Email IN :emails');
        return (List<Contact>) Database.queryWithBinds(
            qf.toSOQL(),
            new Map<String, Object>{ 'emails' => emails },
            AccessLevel.SYSTEM_MODE
        );
    }

    /**
     * @description Generic, injection-safe query over Contact, for callers that
     * need an arbitrary field list / WHERE clause rather than the fixed selector
     * fields. Runs in system mode: the Guest User running self-registration has
     * no Read access to Contact.
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