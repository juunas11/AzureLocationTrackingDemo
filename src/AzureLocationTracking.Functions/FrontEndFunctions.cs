using AzureLocationTracking.Functions.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text;

namespace AzureLocationTracking.Functions;

public class FrontEndFunctions
{
    private static string CachedIndexHtml;
    private static DateTime CachedIndexHtmlLastWrite;
    private readonly string _staticFilesDirectory;
    private readonly AzureMapsService _azureMapsService;

    public FrontEndFunctions(
        AzureMapsService azureMapsService)
    {
        var localRootDirectory = Environment.GetEnvironmentVariable("AzureWebJobsScriptRoot");
        var azureRootDirectory = $"{Environment.GetEnvironmentVariable("HOME")}/site/wwwroot";
        _staticFilesDirectory = localRootDirectory != null
            ? Path.Combine(localRootDirectory, @"..\..\..\", "static")
            : Path.Combine(azureRootDirectory, "static");
        _azureMapsService = azureMapsService;
    }

    [Function(nameof(GetIndex))]
    public async Task<HttpResponseData> GetIndex(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "/")] HttpRequestData req)
    {
        var lastIndexWrite = File.GetLastWriteTime(Path.Combine(_staticFilesDirectory, "index.html"));
        if (CachedIndexHtml == null || lastIndexWrite > CachedIndexHtmlLastWrite)
        {
            var indexTemplate = await File.ReadAllTextAsync(Path.Combine(_staticFilesDirectory, "index.html"));
            CachedIndexHtml = indexTemplate;
            CachedIndexHtmlLastWrite = lastIndexWrite;
        }

        var res = req.CreateResponse(HttpStatusCode.OK);
        res.Headers.Add("Content-Type", "text/html; charset=utf-8");
        await res.WriteStringAsync(CachedIndexHtml, Encoding.UTF8);
        return res;
    }

    [Function(nameof(GetStaticFile))]
    public async Task<HttpResponseData> GetStaticFile(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "static/{**filePath}")] HttpRequestData req,
        string filePath,
        FunctionContext functionContext)
    {
        var logger = functionContext.GetLogger(nameof(GetStaticFile));
        var mappedFilePath = GetStaticFilePath(filePath);

        try
        {
            var res = req.CreateResponse(HttpStatusCode.OK);
            res.Headers.Add("Content-Type", GetContentType(mappedFilePath));
            await res.WriteBytesAsync(await File.ReadAllBytesAsync(mappedFilePath));
            return res;
        }
        catch (FileNotFoundException)
        {
            logger.LogWarning("Unable to find static file at path {filePath}", filePath);
            return req.CreateResponse(HttpStatusCode.NotFound);
        }
    }

    private string GetStaticFilePath(string filePath)
    {
        var fullPath = Path.GetFullPath(Path.Combine(_staticFilesDirectory, filePath));

        if (!IsInDirectory(_staticFilesDirectory, fullPath))
        {
            throw new ArgumentException("Invalid path");
        }

        var isDirectory = Directory.Exists(fullPath);
        if (isDirectory)
        {
            throw new ArgumentException("Invalid path");
        }

        return fullPath;
    }

    private static bool IsInDirectory(string parentPath, string childPath)
    {
        var parent = new DirectoryInfo(parentPath);
        var child = new DirectoryInfo(childPath);

        var dir = child;
        do
        {
            if (dir.FullName == parent.FullName)
            {
                return true;
            }
            dir = dir.Parent;
        } while (dir != null);

        return false;
    }


    private string GetContentType(string filePath)
    {
        var ext = Path.GetExtension(filePath).ToLowerInvariant();
        return ext switch
        {
            ".css" => "text/css",
            ".js" => "application/javascript",
            ".png" => "image/png",
            ".jpg" => "image/jpeg",
            ".jpeg" => "image/jpeg",
            ".gif" => "image/gif",
            ".svg" => "image/svg+xml",
            ".ico" => "image/x-icon",
            ".json" => "application/json",
            ".woff" => "font/woff",
            ".woff2" => "font/woff2",
            ".ttf" => "font/ttf",
            ".eot" => "font/eot",
            ".otf" => "font/otf",
            ".txt" => "text/plain",
            _ => "application/octet-stream",
        };
    }

    [Function(nameof(GetMapsAccessToken))]
    public async Task<HttpResponseData> GetMapsAccessToken(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "api/mapsToken")] HttpRequestData req)
    {
        var res = req.CreateResponse(HttpStatusCode.OK);
        var token = await _azureMapsService.GetRenderTokenAsync();
        await res.WriteStringAsync(token);
        return res;
    }
}
