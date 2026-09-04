/**
 * @description Base application exception for the HFS package. All feature exceptions
 * extend this so hfs_Response.error can distinguish a deliberate, safe business
 * exception from an unexpected system-level one. Carries a machine-readable errorCode.
 */
public virtual class hfs_ApplicationException extends Exception {
  /** Machine-readable error code set at the throw site. */
  public String errorCode { get; private set; }

  /**
   * @description Sets the error code carried by this exception.
   * @param code the stable, machine-readable error code
   */
  public void setErrorCode(String code) {
    this.errorCode = code;
  }
}
