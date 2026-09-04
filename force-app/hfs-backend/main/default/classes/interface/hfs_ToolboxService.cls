/**
 * @description Service interface for the My Toolbox feature. Represents the two
 * read use cases the panel needs. Every Service is an interface plus an
 * implementation, resolved through hfs_Application so it can be mocked in tests.
 * Services throw typed exceptions and never construct an hfs_Response (a
 * Controller-boundary concept).
 */
public interface hfs_ToolboxService {
    /**
     * @description Use case: the running user's enrolled, active programs.
     * @return A ProgramGroupDTO whose listStatus degrades to UNAVAILABLE if the
     *         underlying query fails, so the panel never shows a foreign/empty list.
     */
    hfs_ToolboxDTO.ProgramGroupDTO getMyPrograms();

    /**
     * @description Use case: the ordered Quick Actions list with per-source,
     * resilient counts (each source degrades to UNAVAILABLE independently).
     * @return The ordered list of QuickActionDTO rows.
     */
    List<hfs_ToolboxDTO.QuickActionDTO> getQuickActions();
}