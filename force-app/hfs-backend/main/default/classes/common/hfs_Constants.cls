public with sharing class hfs_Constants {
  /** Error code returned when the Training view fails to load. */
  public static final String TRAINING_LOAD_FAILED = 'TRAINING_LOAD_FAILED';

  public hfs_Constants() {
  }

  /**
   * @description Accessor for TRAINING_LOAD_FAILED, for callers that need it as a method reference.
   * @return the training load-failed error code
   */
  public static String trainingLoadFailed() {
    return TRAINING_LOAD_FAILED;
  }
}
