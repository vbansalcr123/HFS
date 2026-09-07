/**
 * @description Domain class for Contact records created during partner
 * self-registration. Extends fflib_SObjectDomain so object-level defaulting
 * runs through onApplyDefaults(). The Domain mutates records in memory only;
 * persistence is owned by the caller's Unit of Work. Resolve instances via
 * hfs_Application.Domain.newInstance(...) — never `new` this class directly.
 */
public inherited sharing class hfs_ContactsDomain extends fflib_SObjectDomain {
    /**
     * @description Constructs the domain over a set of Contacts.
     * @param sObjectList the Contacts to operate on
     */
    public hfs_ContactsDomain(List<Contact> sObjectList) {
        super(sObjectList);
    }

    /**
     * @description Applies registration defaulting to every Contact in the set:
     * parses the transient full name (staged on LastName) into First / Last and
     * falls back to the email when no usable name is present. Runs automatically
     * for records registered as new work with the Unit of Work, and can be
     * invoked eagerly via hfs_Application.Domain.newInstance(records).
     */
    public override void onApplyDefaults() {
        applyRegistrationDefaults();
    }

    /**
     * @description Parses each Contact's staged full name (on LastName) into
     * First / Last, in memory. Idempotent; never persists.
     * @return this domain, for chaining
     */
    public hfs_ContactsDomain applyRegistrationDefaults() {
        for (Contact record : (List<Contact>) Records) {
            String[] parts = splitName(record.LastName, record.Email);
            record.FirstName = parts[0];
            record.LastName = parts[1];
        }
        return this;
    }

    /**
     * @description Splits a full name into first / last, falling back to email
     * for the last name when the name is blank or single-word.
     * @param fullName the full name to split
     * @param email the fallback value when no usable name is present
     * @return a two-element list: [firstName, lastName]
     */
    private static String[] splitName(String fullName, String email) {
        String firstName;
        String lastName;
        String trimmed = fullName == null ? '' : fullName.trim();
        if (trimmed.contains(' ')) {
            Integer idx = trimmed.lastIndexOf(' ');
            firstName = trimmed.substring(0, idx).trim();
            lastName = trimmed.substring(idx + 1).trim();
        } else {
            firstName = null;
            lastName = String.isBlank(trimmed) ? email : trimmed;
        }
        return new List<String>{ firstName, lastName };
    }

    /**
     * @description fflib domain constructor, resolved by the DomainFactory to
     * build hfs_ContactsDomain instances from a record set.
     */
    public class Constructor implements fflib_SObjectDomain.IConstructable {
        /**
         * @description Builds the domain instance for the given records.
         * @param sObjectList the Contacts to wrap
         * @return the domain instance
         */
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new hfs_ContactsDomain((List<Contact>) sObjectList);
        }
    }
}