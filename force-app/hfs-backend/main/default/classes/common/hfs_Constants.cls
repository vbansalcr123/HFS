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

  // ----------------------------------------------------------------------
  // Error codes - Self-registration domain
  // ----------------------------------------------------------------------

  /** Email or username already exists. */
  public static final String DUPLICATE_EMAIL = 'DUPLICATE_EMAIL';

  /** Provisioning failed; transaction rolled back. */
  public static final String PROVISIONING_FAILED = 'PROVISIONING_FAILED';

  /** Registration configuration metadata is missing. */
  public static final String CONFIG_MISSING = 'CONFIG_MISSING';

  /** Input validation failed at the guard boundary. */
  public static final String VALIDATION = 'VALIDATION';

  // ----------------------------------------------------------------------
  // Error codes - Technical / guard-clause (developer-facing)
  // ----------------------------------------------------------------------

  /** A required payload was empty. */
  public static final String EMPTY_PAYLOAD = 'HFS_TECH_001';

  /** A required argument was null. */
  public static final String NULL_ARGUMENT = 'HFS_TECH_002';

  /** Input was malformed. */
  public static final String MALFORMED_INPUT = 'HFS_TECH_003';
}
