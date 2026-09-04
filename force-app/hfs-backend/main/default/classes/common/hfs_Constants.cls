/**
 * @description Central holder for compile-time-safe application constants (error codes, and any
 * shared literal values). Error codes are Apex constants (not CMDT, not raw string literals),
 * grouped by domain. Each error code pairs to a Custom Label named
 * hfs_Error_<PascalCaseOfCode> for the displayable message.
 */
public class hfs_Constants {
  // ----------------------------------------------------------------------
  // Error codes - Shared / cross-domain
  // ----------------------------------------------------------------------

  /** An unexpected, non-business system error occurred. Domain-neutral fallback. */
  public static final String UNEXPECTED_ERROR = 'UNEXPECTED_ERROR';

  // ----------------------------------------------------------------------
  // Error codes - Training domain
  // ----------------------------------------------------------------------

  /** The training view could not be assembled for the current user. */
  public static final String TRAINING_LOAD_FAILED = 'TRAINING_LOAD_FAILED';
}
