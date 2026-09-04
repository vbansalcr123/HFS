/**
 * @description Thin, cacheable read entry point for the Training LWCs. Declared with sharing (entry
 * point). Delegates to one Service method and wraps the result in hfs_Response, catching its own
 * exceptions so nothing propagates unhandled. Because it is cacheable and catches its own errors, a
 * business failure resolves into the wire's data branch - LWCs must check data.isSuccess.
 */
public with sharing class hfs_TrainingController {
  /**
   * @description Returns the Training view (progress summary + course cards) for the signed-in
   * user, scoped to their own data. On failure returns an error hfs_Response so the LWC renders
   * the unavailable state rather than a zeroed summary.
   * @return hfs_Response whose payload is an hfs_TrainingWrapper on success
   */
  @AuraEnabled(cacheable=true)
  public static hfs_Response getTraining() {
    try {
      hfs_TrainingService service = (hfs_TrainingService) hfs_Application.Service.newInstance(
        hfs_TrainingService.class
      );
      hfs_TrainingWrapper view = service.buildTrainingView(
        UserInfo.getUserId()
      );
      return hfs_Response.success(view);
    } catch (Exception e) {
      // Controller owns its domain fallback for unexpected errors; the shared wrapper
      // stays domain-neutral. Business exceptions surface their own code/message.
      return hfs_Response.error(
        e,
        hfs_Constants.TRAINING_LOAD_FAILED,
        System.Label.hfs_Error_Training_Load_Failed
      );
    }
  }
}
