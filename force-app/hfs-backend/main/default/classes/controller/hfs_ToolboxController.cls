/**
 * @description Single Controller for the My Toolbox feature. It is the only door
 * the LWC calls, exposing all three read use cases:
 *   - getQuickActions()  : ordered Quick Actions with resilient per-source counts
 *   - getMyPrograms()    : the running user's enrolled, active programs
 *   - getAccountLinks()  : the static Account group links
 *
 * The two data-backed methods delegate to hfs_ToolboxService (resolved through
 * hfs_Application); the Controller never touches the Selector layer directly.
 * Every method wraps success in hfs_Response.success(...) and catches at the
 * boundary with hfs_Response.error(e, fallbackCode, fallbackMessage) so error
 * detail never routes through AuraHandledException. A business exception
 * (hfs_ApplicationException) surfaces its own code/message; anything else maps
 * to this controller's own domain fallback.
 */
public with sharing class hfs_ToolboxController {
  /** Domain fallback code/message for unexpected (non-business) errors. */
  @TestVisible
  private static final String FALLBACK_CODE = 'UNEXPECTED';

  /**
   * @description Return the ordered Quick Actions list for the running user.
   * @return hfs_Response whose payload is a List&lt;hfs_ToolboxDTO.QuickActionDTO&gt;.
   */
  @AuraEnabled(cacheable=true)
  public static hfs_Response getQuickActions() {
    try {
      return hfs_Response.success(service().getQuickActions());
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        FALLBACK_CODE,
        System.Label.hfs_Toolbox_Unexpected_Error
      );
    }
  }

  /**
   * @description Return the running user's enrolled programs.
   * @return hfs_Response whose payload is an hfs_ToolboxDTO.ProgramGroupDTO.
   */
  @AuraEnabled(cacheable=true)
  public static hfs_Response getMyPrograms() {
    try {
      return hfs_Response.success(service().getMyPrograms());
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        FALLBACK_CODE,
        System.Label.hfs_Toolbox_Unexpected_Error
      );
    }
  }

  /**
   * @description Return the Account group links for the running user. These are
   * static link metadata (no SObject), so they are built here rather than in the
   * Service/Selector layer.
   * @return hfs_Response whose payload is a List&lt;hfs_ToolboxDTO.AccountLinkDTO&gt;.
   */
  @AuraEnabled(cacheable=true)
  public static hfs_Response getAccountLinks() {
    try {
      List<hfs_ToolboxDTO.AccountLinkDTO> links = new List<hfs_ToolboxDTO.AccountLinkDTO>();
      links.add(
        buildLink(
          System.Label.hfs_Toolbox_Account_My_Profile,
          'utility:user',
          '/my-profile'
        )
      );
      links.add(
        buildLink(
          System.Label.hfs_Toolbox_Account_My_Station_Info,
          'utility:company',
          '/my-station-info'
        )
      );
      links.add(
        buildLink(
          System.Label.hfs_Toolbox_Account_Settings,
          'utility:settings',
          '/settings'
        )
      );
      return hfs_Response.success(links);
    } catch (Exception e) {
      return hfs_Response.error(
        e,
        FALLBACK_CODE,
        System.Label.hfs_Toolbox_Unexpected_Error
      );
    }
  }

  /**
   * @description Resolve the Toolbox Service through the fflib Application factory
   * so it can be mocked in tests.
   * @return the registered hfs_ToolboxService implementation.
   */
  private static hfs_ToolboxService service() {
    return (hfs_ToolboxService) hfs_Application.Service.newInstance(
      hfs_ToolboxService.class
    );
  }

  private static hfs_ToolboxDTO.AccountLinkDTO buildLink(
    String label,
    String icon,
    String url
  ) {
    hfs_ToolboxDTO.AccountLinkDTO dto = new hfs_ToolboxDTO.AccountLinkDTO();
    dto.key = url;
    dto.label = label;
    dto.icon = icon;
    dto.destinationUrl = url;
    return dto;
  }
}
