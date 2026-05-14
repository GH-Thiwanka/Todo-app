import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  ScanCommand,
  UpdateCommand,
  DeleteCommand
} from "@aws-sdk/lib-dynamodb";

import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand
} from "@aws-sdk/client-s3";

import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

// S3 Client
const s3 = new S3Client({
  region: "us-east-1"
});

// DynamoDB Client
const client = new DynamoDBClient({
  region: "us-east-1"
});

const docClient = DynamoDBDocumentClient.from(client);

// Table & Bucket
const TABLE_NAME = "TasksTable";
const BUCKET_NAME = "tasks-image-bucket";

export const handler = async (event) => {

  let body;
  let statusCode = 200;

  const headers = {
    "Content-Type": "application/json"
  };

  try {

    console.log("Method:", event.httpMethod);

    switch (event.httpMethod) {

      // CREATE TASK
      case "POST":

        const {
          taskId,
          taskName,
          status,
          image
        } = JSON.parse(event.body);

        let imageKey = null;

        // Upload image if exists
        if (image) {

          const imageBuffer = Buffer.from(image, "base64");

          imageKey = `tasks/${Date.now()}.jpg`;

          await s3.send(
            new PutObjectCommand({
              Bucket: BUCKET_NAME,
              Key: imageKey,
              Body: imageBuffer,
              ContentType: "image/jpeg"
            })
          );
        }

        // Save task to DynamoDB
        await docClient.send(
          new PutCommand({
            TableName: TABLE_NAME,
            Item: {
              taskId,
              taskName,
              status: status || "pending",
              imageKey
            }
          })
        );

        body = {
          message: "Task Created",
          taskId,
          imageKey
        };

        statusCode = 201;

        break;

      // GET TASKS
      case "GET":

        // Get single task
        if (event.pathParameters?.id) {

          const data = await docClient.send(
            new GetCommand({
              TableName: TABLE_NAME,
              Key: {
                taskId: event.pathParameters.id
              }
            })
          );

          if (!data.Item) {

            statusCode = 404;

            body = {
              message: "Task not found"
            };

          } else {

            let imageUrl = null;

            // Generate signed URL
            if (data.Item.imageKey) {

              imageUrl = await getSignedUrl(
                s3,
                new GetObjectCommand({
                  Bucket: BUCKET_NAME,
                  Key: data.Item.imageKey
                }),
                { expiresIn: 3600 }
              );
            }

            body = {
              ...data.Item,
              imageUrl
            };
          }

        } else {

          // Get all tasks
          const data = await docClient.send(
            new ScanCommand({
              TableName: TABLE_NAME
            })
          );

          const tasks = await Promise.all(
            data.Items.map(async (task) => {

              let imageUrl = null;

              if (task.imageKey) {

                imageUrl = await getSignedUrl(
                  s3,
                  new GetObjectCommand({
                    Bucket: BUCKET_NAME,
                    Key: task.imageKey
                  }),
                  { expiresIn: 3600 }
                );
              }

              return {
                ...task,
                imageUrl
              };
            })
          );

          body = tasks;
        }

        break;

      // UPDATE TASK
      case "PUT":

        const id = event.pathParameters.id;

        const {
          taskName: newName,
          status: newStatus
        } = JSON.parse(event.body);

        await docClient.send(
          new UpdateCommand({
            TableName: TABLE_NAME,
            Key: {
              taskId: id
            },
            UpdateExpression:
              "set taskName = :n, #s = :s",

            ExpressionAttributeValues: {
              ":n": newName,
              ":s": newStatus
            },

            ExpressionAttributeNames: {
              "#s": "status"
            }
          })
        );

        body = {
          message: "Task Updated"
        };

        break;

      // DELETE TASK
      case "DELETE":

        const taskData = await docClient.send(
          new GetCommand({
            TableName: TABLE_NAME,
            Key: {
              taskId: event.pathParameters.id
            }
          })
        );

        // Delete image from S3
        if (taskData.Item?.imageKey) {

          await s3.send(
            new DeleteObjectCommand({
              Bucket: BUCKET_NAME,
              Key: taskData.Item.imageKey
            })
          );
        }

        // Delete task from DynamoDB
        await docClient.send(
          new DeleteCommand({
            TableName: TABLE_NAME,
            Key: {
              taskId: event.pathParameters.id
            }
          })
        );

        body = {
          message: "Task Deleted"
        };

        break;

      default:

        throw new Error(
          `Unsupported method "${event.httpMethod}"`
        );
    }

  } catch (err) {

    console.error(err);

    statusCode = 400;

    body = {
      error: err.message
    };
  }

  return {
    statusCode,
    headers,
    body: JSON.stringify(body)
  };
};