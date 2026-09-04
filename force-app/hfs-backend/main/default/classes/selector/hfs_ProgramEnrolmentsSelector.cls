/**
 * @description Selector for hfs_Program_Enrolment__c. Centralizes all SOQL for
 * the enrolment object (Selector layer — no business logic). Exposes a single
 * generic query method; the Service layer builds the WHERE clause and binds.
 * USER_MODE enforces CRUD/FLS/sharing so a user only ever reads their own rows.
 */
public inherited sharing class hfs_ProgramEnrolmentsSelector extends fflib_SObjectSelector {
    /**
     * @description The SObject this selector queries.
     * @return hfs_Program_Enrolment__c SObjectType.
     */
    public Schema.SObjectType getSObjectType() {
        return hfs_Program_Enrolment__c.SObjectType;
    }

    /**
     * @description Base field list queried by the fflib base helpers.
     * @return The enrolment fields plus the parent Program fields the panel needs.
     */
    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            hfs_Program_Enrolment__c.Id,
            hfs_Program_Enrolment__c.hfs_Program__c,
            hfs_Program_Enrolment__c.hfs_Member__c,
            hfs_Program_Enrolment__c.hfs_Status__c
        };
    }

    /**
     * @description Generic, injection-safe query. The Service supplies the WHERE
     * clause and bind map; USER_MODE enforces FLS/CRUD/sharing.
     * @param whereClause SOQL WHERE body (without the WHERE keyword), using named binds.
     * @param binds Bind variable map referenced by whereClause.
     * @return Matching enrolment rows with the parent Program fields the panel needs.
     */
    public List<hfs_Program_Enrolment__c> getProgramEnrolmentRecords(
        String whereClause, Map<String, Object> binds
    ) {
        String query =
            'SELECT hfs_Program__c, hfs_Program__r.Name, ' +
            'hfs_Program__r.hfs_Destination_URL__c, hfs_Program__r.hfs_Icon__c, ' +
            'hfs_Program__r.hfs_Sort_Order__c ' +
            'FROM hfs_Program_Enrolment__c ' +
            (String.isBlank(whereClause) ? '' : 'WHERE ' + whereClause + ' ') +
            'ORDER BY hfs_Program__r.hfs_Sort_Order__c ASC NULLS LAST';
        return (List<hfs_Program_Enrolment__c>) Database.queryWithBinds(
            query,
            binds == null ? new Map<String, Object>() : binds,
            AccessLevel.USER_MODE
        );
    }
}