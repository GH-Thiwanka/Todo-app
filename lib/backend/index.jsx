import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { 
    DynamoDBDocumentClient, 
    PutCommand, 
    GetCommand, 
    ScanCommand, 
    UpdateCommand, 
    DeleteCommand 
} from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({ region: "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = "TasksTable";

export const handler = async (event) => {
    let body;
    let statusCode = 200;
    const headers = { "Content-Type": "application/json" };

    try {
        // Log the event for easier debugging in CloudWatch
        console.log("Method:", event.httpMethod);

        switch (event.httpMethod) {
            case "POST":
                const { taskId, taskName, status } = JSON.parse(event.body);
                await docClient.send(new PutCommand({
                    TableName: TABLE_NAME,
                    Item: { taskId, taskName, status: status || "pending" }
                }));
                body = { message: "Task Created", taskId };
                statusCode = 201;
                break;

            case "GET":
                if (event.pathParameters?.id) {
                    const data = await docClient.send(new GetCommand({
                        TableName: TABLE_NAME,
                        Key: { taskId: event.pathParameters.id }
                    }));
                    body = data.Item || { message: "Task not found" };
                    if (!data.Item) statusCode = 404;
                } else {
                    const data = await docClient.send(new ScanCommand({ TableName: TABLE_NAME }));
                    body = data.Items;
                }
                break;

            case "PUT":
                const id = event.pathParameters.id;
                const { taskName: newName, status: newStatus } = JSON.parse(event.body);
                await docClient.send(new UpdateCommand({
                    TableName: TABLE_NAME,
                    Key: { taskId: id },
                    UpdateExpression: "set taskName = :n, #s = :s",
                    ExpressionAttributeValues: { ":n": newName, ":s": newStatus },
                    ExpressionAttributeNames: { "#s": "status" }
                }));
                body = { message: "Task Updated" };
                break;

            case "DELETE":
                await docClient.send(new DeleteCommand({
                    TableName: TABLE_NAME,
                    Key: { taskId: event.pathParameters.id }
                }));
                body = { message: "Task Deleted" };
                break;

            default:
                throw new Error(`Unsupported method "${event.httpMethod}"`);
        }
    } catch (err) {
        console.error(err);
        statusCode = 400;
        body = { error: err.message };
    }

    return { 
        statusCode, 
        headers, 
        body: JSON.stringify(body) 
    };
};