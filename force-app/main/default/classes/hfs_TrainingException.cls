/**
 * @description Typed exception for the Training action layer (HFS-34). Extends
 * hfs_ApplicationException so hfs_Response.error(...) can distinguish it as a deliberate,
 * safe business exception and surface its own error code / message rather than a generic
 * fallback. Carries a machine-readable error code from hfs_Constants set at the throw site.
 */
public virtual class hfs_TrainingException extends hfs_ApplicationException {
  /**
   * @description Builds a training exception carrying both its error code and message.
   * @param errorCode the stable, machine-readable error code (from hfs_Constants)
   * @param message the exception message
   */
  public hfs_TrainingException(String errorCode, String message) {
    super(errorCode, message);
  }
}
