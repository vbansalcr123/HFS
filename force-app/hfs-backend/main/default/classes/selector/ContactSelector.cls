public with sharing class ContactSelector {

    public static List<Contact> selectById(Set<Id> contactIds) {
        return [
            SELECT Id, FirstName, LastName, Email, HasOptedOutOfEmail
            FROM Contact
            WHERE Id IN :contactIds
        ];
    }
}
