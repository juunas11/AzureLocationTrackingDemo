#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["AzureLocationTracking.TrackerDevice/AzureLocationTracking.TrackerDevice.csproj", "AzureLocationTracking.TrackerDevice/"]
RUN dotnet restore "AzureLocationTracking.TrackerDevice/AzureLocationTracking.TrackerDevice.csproj"
COPY . .
WORKDIR "/src/AzureLocationTracking.TrackerDevice"
RUN dotnet build "AzureLocationTracking.TrackerDevice.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "AzureLocationTracking.TrackerDevice.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "AzureLocationTracking.TrackerDevice.dll"]