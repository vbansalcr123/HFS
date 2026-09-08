/**
 * @description Service interface for the Home dashboard use case (HFS-32). A Service method
 * represents a use case, not a CRUD wrapper. The implementation assembles the personalised
 * dashboard DTO (account summary, four tiles, optional announcement) for the signed-in partner.
 */
public interface hfs_HomeDashboardService {
  /**
   * @description Builds the personalised Home dashboard payload for the given user, scoped to
   * their own data. Each tile is computed independently so a single failing source degrades
   * gracefully to an UNAVAILABLE state rather than zeroing or blocking the others.
   * @param userId the signed-in user whose dashboard should be assembled
   * @return the populated dashboard DTO
   */
  hfs_HomeDashboardDTO buildDashboard(Id userId);
}