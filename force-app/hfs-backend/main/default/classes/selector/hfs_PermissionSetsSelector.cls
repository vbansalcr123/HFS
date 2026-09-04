/**
 * @description Selector for PermissionSet. Resolves the partner permission set
 * Id by API name (from config) so no Id is ever hard-coded. Runs in SYSTEM_MODE:
 * called only from the elevated (guest) self-registration provisioning flow,
 * where the Guest User has no read access to PermissionSet.
 */
public inherited sharing class hfs_PermissionSetsSelector {
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