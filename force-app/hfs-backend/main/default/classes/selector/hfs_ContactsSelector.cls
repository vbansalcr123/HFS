/**
 * @description fflib Selector for Contact, registered in hfs_Application.Selector.
 * Centralises the Contact field list and standard id-based selection through the
 * fflib QueryFactory (enforces FLS/CRUD). Email-based duplicate detection remains
 * in hfs_ContactsGenericSelector's generic query path used by the Service.
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
}