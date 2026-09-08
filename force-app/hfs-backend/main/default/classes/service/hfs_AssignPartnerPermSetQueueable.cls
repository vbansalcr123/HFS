/**
 * @description Assigns the partner permission set to a freshly-provisioned portal
 * User in its OWN transaction. Self-registration inserts the Account, Contact and
 * portal User synchronously (allowed together because the portal User carries a
 * null UserRoleId), but PermissionSetAssignment is a setup object and cannot share
 * that transaction — mixing it triggers MIXED_DML_OPERATION. Enqueuing this job
 * runs the assignment in a separate transaction, clearing the mixed-DML conflict
 * while keeping provisioning fail-closed (the User is inactive until the user
 * clicks the emailed set-password link, so a failed assignment cannot expose
 * unentitled access). Runs "without sharing" because it executes in the elevated
 * guest registration context.
 */
public without sharing class hfs_AssignPartnerPermSetQueueable implements Queueable {
    private final Id userId;
    private final Id permSetId;

    /**
     * @description Creates the job.
     * @param userId the created portal User Id
     * @param permSetId the partner permission set Id
     */
    public hfs_AssignPartnerPermSetQueueable(Id userId, Id permSetId) {
        this.userId = userId;
        this.permSetId = permSetId;
    }

    /**
     * @description Inserts the permission-set assignment in its own transaction.
     * A PermissionSetAssignment-only insert never mixes with non-setup DML, so it
     * is safe here. Failures are logged; the inactive User stays fail-closed.
     * @param context the Queueable context
     */
    public void execute(QueueableContext context) {
        if (userId == null || permSetId == null) {
            return;
        }
        try {
            insert new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = permSetId
            );
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'hfs partner permission-set assignment failed for user ' + userId + ': ' + e.getMessage()
            );
        }
    }
}