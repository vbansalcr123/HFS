/**
 * @description Shared, project-wide Controller response wrapper. Lives at the Controller layer
 * only. Sidesteps the AuraHandledException message-stripping gotcha by never routing error
 * detail through the exception mechanism. LWCs must check isSuccess before touching payload.
 */
public class hfs_Response {
  /** True when the operation succeeded. */
  @AuraEnabled
  public Boolean isSuccess { get; set; }

  /** DTO / wrapper payload on success (never a raw SObject). */
  @AuraEnabled
  public Object payload { get; set; }

  /** Safe-to-display error message (from a Custom Label) on failure. */
  @AuraEnabled
  public String errorMessage { get; set; }

  /** Machine-readable error code that lets an LWC branch without string matching. */
  @AuraEnabled
  public String errorCode { get; set; }

  /**
   * @description Builds a success response wrapping the given payload.
   * @param payload the DTO / wrapper to return
   * @return a populated success hfs_Response
   */
  public static hfs_Response success(Object payload) {
    hfs_Response response = new hfs_Response();
    response.isSuccess = true;
    response.payload = payload;
    return response;
  }

  /**
   * @description Builds an error response from a caught exception. A deliberate business
   * exception (hfs_ApplicationException) surfaces its own message/code; anything else is
   * treated as an unexpected system error with a safe generic message.
   * @param e the caught exception
   * @return a populated error hfs_Response
   */
  public static hfs_Response error(Exception e) {
    hfs_Response response = new hfs_Response();
    response.isSuccess = false;
    if (e instanceof hfs_ApplicationException) {
      hfs_ApplicationException appEx = (hfs_ApplicationException) e;
      response.errorCode = appEx.errorCode;
      response.errorMessage = e.getMessage();
    } else {
      response.errorCode = hfs_Constants.TRAINING_LOAD_FAILED;
      response.errorMessage = System.Label.hfs_Error_Training_Load_Failed;
    }
    return response;
  }
}
