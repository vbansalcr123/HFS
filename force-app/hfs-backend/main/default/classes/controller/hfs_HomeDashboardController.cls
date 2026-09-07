/**
 * @description Thin, cacheable read entry point for the Home dashboard LWC (HFS-32). Declared with
 * sharing (entry point) so the Customer Community Plus role/sharing model scopes every read to the
 * running partner's own data. Delegates to one Service method and wraps the result in hfs_Response,
 * catching its own exceptions so nothing propagates unhandled. Because it is cacheable and catches
 * its own errors, a business failure resolves into the wire's data branch - the LWC must check
 * data.isSuccess.
 */
public with sharing class hfs_HomeDashboardController {
  /**
   * @description Returns the personalised Home dashboard (greeting, account summary, four tiles,
   * optional announcement banner) for the signed-in partner, scoped to their own data. On failure
   * returns an error hfs_Response so the LWC renders the unavailable state rather than a zeroed
   * dashboard.
   * @return hfs_Response whose payload is an hfs_HomeDashboardDTO on success
   */
  @AuraEnabled(cacheable=true)
  public static hfs_Response getHomeDashboard() {
    try {
      hfs_HomeDashboardService service = (hfs_HomeDashboardService) hfs_Application.Service.newInstance(
        hfs_HomeDashboardService.class
      );
      hfs_HomeDashboardDTO dashboard = service.buildDashboard(
        UserInfo.getUserId()
      );
      return hfs_Response.success(dashboard);
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        hfs_Constants.HOME_DASHBOARD_LOAD_FAILED,
        System.Label.hfs_Error_Home_Dashboard_Load_Failed
      );
    }
  }
}