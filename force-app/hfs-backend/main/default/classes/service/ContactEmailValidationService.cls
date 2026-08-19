public with sharing class ContactEmailValidationService {

    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');

    public static void validateEmails(Set<Id> contactIds) {
        List<Contact> contacts = ContactSelector.selectById(contactIds);
        List<Contact> contactsToUpdate = new List<Contact>();

        for (Contact con : contacts) {
            Boolean shouldOptOut = !isValidEmail(con.Email);
            if (con.HasOptedOutOfEmail != shouldOptOut) {
                con.HasOptedOutOfEmail = shouldOptOut;
                contactsToUpdate.add(con);
            }
        }

        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    public static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        return EMAIL_PATTERN.matcher(email).matches();
    }
}
