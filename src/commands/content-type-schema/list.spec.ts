import { handler, parseDataPresenter } from './list';
import dynamicContentClientFactory from '../../services/dynamic-content-client-factory';
import DataPresenter from '../../view/data-presenter';
import { ContentTypeSchema } from 'dc-management-sdk-js';
import MockPage from '../../common/dc-management-sdk-js/mock-page';

jest.mock('../../services/dynamic-content-client-factory');
jest.mock('../../view/data-presenter');

describe('content-type-schema list command', (): void => {
  afterEach((): void => {
    jest.restoreAllMocks();
  });

  it('should page the data', async (): Promise<void> => {
    const yargArgs = {
      $0: 'test',
      _: ['test']
    };
    const config = {
      clientId: 'client-id',
      clientSecret: 'client-id',
      hubId: 'hub-id'
    };

    const pagingOptions = { page: 3, size: 10, sort: 'createdDate,desc' };

    const contentTypeSchemaResponse: ContentTypeSchema[] = [new ContentTypeSchema()];

    const listResponse = new MockPage(ContentTypeSchema, contentTypeSchemaResponse);
    const mockList = jest.fn().mockResolvedValue(listResponse);

    const mockGetHub = jest.fn().mockResolvedValue({
      related: {
        contentTypeSchema: {
          list: mockList
        }
      }
    });

    (dynamicContentClientFactory as jest.Mock).mockReturnValue({
      hubs: {
        get: mockGetHub
      }
    });

    const mockParse = jest.fn();
    const mockRender = jest.fn();
    const mockDataPresenter = DataPresenter as jest.Mock;
    mockDataPresenter.mockImplementation(() => ({
      parse: mockParse.mockReturnThis(),
      render: mockRender.mockReturnThis()
    }));

    const argv = { ...yargArgs, ...config, ...pagingOptions };
    await handler(argv);

    expect(mockGetHub).toBeCalledWith('hub-id');
    expect(mockList).toBeCalledWith(pagingOptions);

    expect(mockDataPresenter).toHaveBeenCalledWith(argv, listResponse);
    expect(mockParse).toHaveBeenCalledWith(parseDataPresenter);
    expect(mockRender).toHaveBeenCalled();
  });

  it('should run the formatRow function', async (): Promise<void> => {
    const contentTypeSchema = new ContentTypeSchema({
      id: 'id',
      schemaId: 'schemaId',
      version: 'version',
      validationLevel: 'validationLevel',
      body: '{}'
    });
    const contentTypeSchemaPage = new MockPage(ContentTypeSchema, [contentTypeSchema]);
    const result = parseDataPresenter(contentTypeSchemaPage);
    expect(result).toEqual([
      {
        id: 'id',
        schemaId: 'schemaId',
        validationLevel: 'validationLevel',
        version: 'version'
      }
    ]);
  });
});
