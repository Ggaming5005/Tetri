FROM mcr.microsoft.com/dotnet/sdk:10.0.403 AS build
WORKDIR /source
COPY global.json ./
COPY backend/ backend/
RUN dotnet restore backend/src/Tetri.Api/Tetri.Api.csproj --locked-mode
RUN dotnet publish backend/src/Tetri.Api/Tetri.Api.csproj --configuration Release --no-restore --output /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0.14 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "Tetri.Api.dll"]
