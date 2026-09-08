/**
 * @description Assigns the partner permission set to a freshly-provisioned portal
 * User in its OWN transaction. Self-registration inserts the Account, Contact and
 * portal User synchronously (allowed together because the portal User carries a
 * null UserRoleId), but PermissionSetAssignment is a setup object and cannot share
 * that transaction — mixing it triggers MIXED_DML_OPERATION. Enqueuing this job
 * runs the assignment in a separate transaction, clearing the mixed-DML conflict.
 * The portal User is created ACTIVE with its password already set (no
 * set-password email / inactive-until-click flow), so a failed assignment here
 * leaves a real, already-logged-in User missing its permission set — this is not
 * a safe no-op. execute() lets the failure propagate (after logging) so the job
 * surfaces as Failed in Setup > Apex Jobs, rather than only in debug logs. Runs
 * "without sharing" because it executes in the elevated guest registration
 * context.
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
     * @description Inserts the permission-set assignment in its own transaction
     * via the fflib Unit of Work (never a raw DML statement), consistent with
     * how the rest of the codebase writes records. Logs and rethrows on failure:
     * the User this assigns to is already active with its password set, so a
     * failure here is a real gap (not a safe fail-closed state) and must surface
     * as a Failed Apex Job for an admin to notice and retry, not just a debug log.
     * @param context the Queueable context
     */
    public void execute(QueueableContext context) {
        if (userId == null || permSetId == null) {
            return;
        }
        try {
            fflib_ISObjectUnitOfWork uow = hfs_Application.UnitOfWork.newInstance();
            uow.registerNew(new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = permSetId
            ));
            uow.commitWork();
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'hfs partner permission-set assignment failed for already-active user '
                    + userId + ': ' + e.getMessage() + '\n' + e.getStackTraceString()
            );
            throw e;
        }
    }
}