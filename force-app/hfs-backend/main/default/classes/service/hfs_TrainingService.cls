/**
 * @description Service interface for the Training use case. Every Service is an interface plus an
 * implementation. A Service method represents a use case, not a CRUD wrapper.
 */
public interface hfs_TrainingService {
  /**
   * @description Builds the Training view (progress summary + course cards) for the given user.
   * @param userId the user whose training view should be assembled
   * @return the populated Training view wrapper
   */
  hfs_TrainingWrapper buildTrainingView(Id userId);
}
