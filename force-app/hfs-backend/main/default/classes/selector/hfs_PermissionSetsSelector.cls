/**
 * @description fflib Selector for PermissionSet, registered in hfs_Application.Selector.
 * Resolves the partner permission set Id by API name (from config) so no Id is ever
 * hard-coded. Runs in SYSTEM_MODE: called only from the elevated (guest)
 * self-registration provisioning flow, where the Guest User has no read access to
 * PermissionSet.
 */
public inherited sharing class hfs_PermissionSetsSelector extends fflib_SObjectSelector {
    /**
     * @description The SObject this selector queries.
     * @return PermissionSet.SObjectType
     */
    public Schema.SObjectType getSObjectType() {
        return PermissionSet.SObjectType;
    }

    /**
     * @description The default field list selected by this selector.
     * @return the PermissionSet fields
     */
    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{ PermissionSet.Id, PermissionSet.Name };
    }

    /**
     * @description Resolves a PermissionSet Id by its API name.
     * @param apiName the permission set Name (API name)
     * @return the PermissionSet Id, or null when not found
     */
    public Id getPermissionSetIdByName(String apiName) {
        List<PermissionSet> sets = [
            SELECT Id FROM PermissionSet WHERE Name = :apiName WITH SYSTEM_MODE LIMIT 1
        ];
        return sets.isEmpty() ? null : sets[0].Id;
    }
}