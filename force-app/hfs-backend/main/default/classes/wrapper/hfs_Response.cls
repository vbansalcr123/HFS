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
   * @description Builds an error response from a caught exception, letting the calling
   * controller supply its own domain fallback for unexpected (non-business) errors. A
   * deliberate business exception (hfs_ApplicationException) always surfaces its own
   * message/code; the fallback applies only to unexpected system-level exceptions. This
   * keeps the shared wrapper domain-neutral - the error semantics stay with the service's
   * own controller.
   * @param e the caught exception
   * @param fallbackCode machine-readable code to use for an unexpected error
   * @param fallbackMessage safe-to-display message (from a Custom Label) for an unexpected error
   * @return a populated error hfs_Response
   */
  public static hfs_Response error(
    Exception e,
    String fallbackCode,
    String fallbackMessage
  ) {
    hfs_Response response = new hfs_Response();
    response.isSuccess = false;
    if (e instanceof hfs_ApplicationException) {
      hfs_ApplicationException appEx = (hfs_ApplicationException) e;
      response.errorCode = appEx.errorCode;
      response.errorMessage = e.getMessage();
    } else {
      response.errorCode = fallbackCode;
      response.errorMessage = fallbackMessage;
    }
    return response;
  }
}
