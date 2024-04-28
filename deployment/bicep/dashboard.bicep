param location string = resourceGroup().location
param containerAppName string
param appInsightsName string
param signalRName string
param sqlServerName string
param sqlDbName string
param eventHubNamespaceName string
param prodLocationDataEventHubName string
param iotHubName string
param adxClusterName string

resource containerApp 'Microsoft.App/containerApps@2022-03-01' existing = {
  name: containerAppName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource signalR 'Microsoft.SignalRService/signalR@2022-08-01-preview' existing = {
  name: signalRName
}

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' existing = {
  name: sqlServerName
}

resource sqlDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' existing = {
  parent: sqlServer
  name: sqlDbName
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: eventHubNamespaceName
}

resource iotHub 'Microsoft.Devices/IotHubs@2021-07-02' existing = {
  name: iotHubName
}

resource adxCluster 'Microsoft.Kusto/clusters@2022-12-29' existing = {
  name: adxClusterName
}

resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: 'dash-locationtracking'
  location: location
  tags: {
    'hidden-title': 'Location Tracking'
  }
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: {
              x: 0
              y: 0
              colSpan: 7
              rowSpan: 9
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/ResourceGroupMapPinnedPart'
              inputs: [
                {
                  name: 'resourceGroup'
                  isOptional: true
                }
                {
                  name: 'id'
                  value: resourceGroup().id
                  isOptional: true
                }
              ]
            }
          }
          {
            position: {
              x: 0
              y: 9
              rowSpan: 4
              colSpan: 7
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: signalR.id
                          }
                          name: 'OutboundTraffic'
                          aggregationType: 1
                          namespace: 'microsoft.signalrservice/signalr'
                          metricVisualization: {
                            displayName: 'Outbound traffic'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: signalR.id
                          }
                          name: 'InboundTraffic'
                          aggregationType: 1
                          namespace: 'microsoft.signalrservice/signalr'
                          metricVisualization: {
                            displayName: 'Inbound traffic'
                          }
                        }
                      ]
                      title: 'SignalR traffic'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 7
              y: 0
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: containerApp.id
                          }
                          name: 'Replicas'
                          aggregationType: 3
                          namespace: 'microsoft.app/containerapps'
                          metricVisualization: {
                            displayName: 'Replica count'
                          }
                        }
                      ]
                      title: 'Container App replicas'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 13
              y: 0
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/Location update event processing time (ms)'
                          aggregationType: 4
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Average processing time (ms)'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/Location update event processing time (ms)'
                          aggregationType: 2
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Minimum processing time (ms)'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/Location update event processing time (ms)'
                          aggregationType: 3
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Maximum processing time (ms)'
                          }
                        }
                      ]
                      title: 'Event end-to-end processing time'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 7
              y: 4
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/UpdateLatestLocations Successes'
                          aggregationType: 1
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Latest location Successes'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/UpdateLatestLocations Failures'
                          aggregationType: 1
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Latest location Failures'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/CheckGeofences Successes'
                          aggregationType: 1
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Geofence Successes'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/CheckGeofences Failures'
                          aggregationType: 1
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Geofence Failures'
                          }
                        }
                      ]
                      title: 'Data processor success & failure'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 13
              y: 4
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/UpdateLatestLocations AvgDurationMs'
                          aggregationType: 4
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Latest location Average duration'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/UpdateLatestLocations MinDurationMs'
                          aggregationType: 2
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Latest location Minimum duration'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/UpdateLatestLocations MaxDurationMs'
                          aggregationType: 3
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Latest location Maximum duration'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/CheckGeofences AvgDurationMs'
                          aggregationType: 4
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Geofence Average duration'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/CheckGeofences MinDurationMs'
                          aggregationType: 2
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Geofence Minimum duration'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/CheckGeofences MaxDurationMs'
                          aggregationType: 3
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Geofence Maximum duration'
                          }
                        }
                      ]
                      title: 'Data processor processing time'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 19
              y: 4
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: adxCluster.id
                          }
                          name: 'IngestionLatencyInSeconds'
                          aggregationType: 4
                          namespace: 'microsoft.kusto/clusters'
                          metricVisualization: {
                            displayName: 'Ingestion latency'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: adxCluster.id
                          }
                          name: 'BatchDuration'
                          aggregationType: 4
                          namespace: 'microsoft.kusto/clusters'
                          metricVisualization: {
                            displayName: 'Batch duration'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: adxCluster.id
                          }
                          name: 'DiscoveryLatency'
                          aggregationType: 4
                          namespace: 'microsoft.kusto/clusters'
                          metricVisualization: {
                            displayName: 'Discovery latency'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: adxCluster.id
                          }
                          name: 'StageLatency'
                          aggregationType: 4
                          namespace: 'microsoft.kusto/clusters'
                          metricVisualization: {
                            displayName: 'Stage latency'
                          }
                        }
                      ]
                      title: 'ADX performance'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 7
              y: 8
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: signalR.id
                          }
                          name: 'MessageCount'
                          aggregationType: 1
                          namespace: 'microsoft.signalrservice/signalr'
                          metricVisualization: {
                            displayName: 'Message count'
                          }
                        }
                      ]
                      title: 'SignalR messages'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 13
              y: 8
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: sqlDb.id
                          }
                          name: 'dtu_consumption_percent'
                          aggregationType: 4
                          namespace: 'microsoft.sql/servers/databases'
                          metricVisualization: {
                            displayName: 'Average DTU %'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: sqlDb.id
                          }
                          name: 'dtu_consumption_percent'
                          aggregationType: 2
                          namespace: 'microsoft.sql/servers/databases'
                          metricVisualization: {
                            displayName: 'Min DTU %'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: sqlDb.id
                          }
                          name: 'dtu_consumption_percent'
                          aggregationType: 3
                          namespace: 'microsoft.sql/servers/databases'
                          metricVisualization: {
                            displayName: 'Max DTU %'
                          }
                        }
                      ]
                      title: 'SQL DB'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 19
              y: 8
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: adxCluster.id
                          }
                          name: 'IngestionVolumeInMB'
                          aggregationType: 1
                          namespace: 'microsoft.kusto/clusters'
                          metricVisualization: {
                            displayName: 'Ingestion volume'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: adxCluster.id
                          }
                          name: 'ReceivedDataSizeBytes'
                          aggregationType: 4
                          namespace: 'microsoft.kusto/clusters'
                          metricVisualization: {
                            displayName: 'Received data size'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: adxCluster.id
                          }
                          name: 'BatchSize'
                          aggregationType: 4
                          namespace: 'microsoft.kusto/clusters'
                          metricVisualization: {
                            displayName: 'Batch size'
                          }
                        }
                      ]
                      title: 'ADX volume'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 19
              y: 0
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              #disable-next-line BCP037
              filters: {
                EntityName: {
                  model: {
                    operator: 'equals'
                    values: [
                      prodLocationDataEventHubName
                    ]
                  }
                }
              }
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: eventHubNamespace.id
                          }
                          name: 'IncomingMessages'
                          aggregationType: 1
                          namespace: 'microsoft.eventhub/namespaces'
                          metricVisualization: {
                            displayName: 'Incoming messages'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: eventHubNamespace.id
                          }
                          name: 'OutgoingMessages'
                          aggregationType: 1
                          namespace: 'microsoft.eventhub/namespaces'
                          metricVisualization: {
                            displayName: 'Outgoing messages'
                          }
                        }
                      ]
                      title: 'Event Hub'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 7
              y: 12
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      title: 'IoT Hub D2C'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                      metrics: [
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.telemetry.ingress.success'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Sent messages'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.telemetry.ingress.allProtocol'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Attempted messages'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.endpoints.egress.eventHubs'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Messages to Event Hubs'
                          }
                        }
                      ]
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 13
              y: 12
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      title: 'IoT Hub Device Twin success'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                      metrics: [
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.twin.read.success'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Reads from device'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.twin.update.success'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Updates from device'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'c2d.twin.update.success'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Updates from cloud'
                          }
                        }
                      ]
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 19
              y: 12
              colSpan: 6
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      title: 'IoT Hub Failures'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                      metrics: [
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.twin.read.failure'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Twin read fails'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'c2d.twin.update.failure'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Twin update fails from cloud'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.twin.update.failure'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Twin update fails from device'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.telemetry.egress.dropped'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Dropped messages'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.telemetry.egress.invalid'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Incompatible messages'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.telemetry.egress.orphaned'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Orphaned messages'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: iotHub.id
                          }
                          name: 'd2c.telemetry.egress.fallback'
                          aggregationType: 1
                          namespace: 'microsoft.devices/iothubs'
                          metricVisualization: {
                            displayName: 'Messages to fallback'
                          }
                        }
                      ]
                    }
                  }
                }
              ]
            }
          }
          {
            position: {
              x: 0
              y: 13
              colSpan: 7
              rowSpan: 4
            }
            metadata: {
              #disable-next-line BCP036
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
                {
                  name: 'options'
                  isOptional: true
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/Event Hub batch size'
                          aggregationType: 4
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Avg batch size'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/Event Hub batch size'
                          aggregationType: 2
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Min batch size'
                          }
                        }
                        {
                          resourceMetadata: {
                            id: appInsights.id
                          }
                          name: 'customMetrics/Event Hub batch size'
                          aggregationType: 3
                          namespace: 'microsoft.insights/components/kusto'
                          metricVisualization: {
                            displayName: 'Max batch size'
                          }
                        }
                      ]
                      title: 'Event Hub batch size'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                      }
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    ]
  }
}
