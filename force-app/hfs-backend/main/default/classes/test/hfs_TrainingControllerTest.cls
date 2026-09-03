/**
 * @description Tests for hfs_TrainingController. Asserts directly on hfs_Response - isSuccess/payload
 * for the success path and isSuccess=false/errorMessage/errorCode for the failure path. The Service
 * is mocked so the Controller is tested in isolation.
 */
@IsTest
private class hfs_TrainingControllerTest {
  /**
   * @description Success path - a mocked Service returns a view; the Controller wraps it in a
   * success hfs_Response with the wrapper as payload.
   */
  @IsTest
  static void getTraining_success_returnsWrappedView() {
    hfs_TrainingWrapper view = new hfs_TrainingWrapper();
    view.summary = new hfs_TrainingWrapper.Summary();
    view.summary.coursesTotal = 5;

    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_TrainingService service = (hfs_TrainingService) mocks.mock(
      hfs_TrainingService.class
    );
    mocks.startStubbing();
    mocks.when(service.buildTrainingView(fflib_Match.anyId())).thenReturn(view);
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_TrainingService.class, service);

    Test.startTest();
    hfs_Response response = hfs_TrainingController.getTraining();
    Test.stopTest();

    System.Assert.isTrue(
      response.isSuccess,
      'Success path returns isSuccess = true'
    );
    System.Assert.isNotNull(response.payload, 'Payload carries the view');
    hfs_TrainingWrapper payload = (hfs_TrainingWrapper) response.payload;
    System.Assert.areEqual(
      5,
      payload.summary.coursesTotal,
      'Payload is the mocked view'
    );
  }

  /**
   * @description Failure path - a mocked Service throws; the Controller catches and returns an
   * error hfs_Response with a safe message and code (not the raw exception).
   */
  @IsTest
  static void getTraining_serviceThrows_returnsErrorResponse() {
    fflib_ApexMocks mocks = new fflib_ApexMocks();
    hfs_TrainingService service = (hfs_TrainingService) mocks.mock(
      hfs_TrainingService.class
    );
    mocks.startStubbing();
    mocks.when(service.buildTrainingView(fflib_Match.anyId()))
      .thenThrow(new System.QueryException('boom'));
    mocks.stopStubbing();
    hfs_Application.Service.setMock(hfs_TrainingService.class, service);

    Test.startTest();
    hfs_Response response = hfs_TrainingController.getTraining();
    Test.stopTest();

    System.Assert.isFalse(
      response.isSuccess,
      'Failure path returns isSuccess = false'
    );
    System.Assert.areEqual(
      hfs_Constants.TRAINING_LOAD_FAILED,
      response.errorCode,
      'Unexpected error maps to the training load-failed code'
    );
    System.Assert.isNotNull(
      response.errorMessage,
      'A safe error message is present'
    );
  }

  /**
   * @description Covers the application exception carrier and the constants holder so
   * these low-logic classes contribute to org-wide coverage.
   */
  @IsTest
  static void applicationException_carriesErrorCode() {
    Test.startTest();
    hfs_ApplicationException ex = new hfs_ApplicationException();
    ex.setMessage('boom');
    ex.setErrorCode(hfs_Constants.TRAINING_LOAD_FAILED);
    String code = hfs_Constants.trainingLoadFailed();
    Test.stopTest();

    System.Assert.areEqual(
      hfs_Constants.TRAINING_LOAD_FAILED,
      ex.errorCode,
      'Error code should be carried by the exception'
    );
    System.Assert.isNotNull(code, 'Error code constant should be defined');
  }
}
