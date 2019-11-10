"""
*****************************************************************************

Author:     Arnab Kumar Ray
Purpose:    This script captures WebLogic server's statistics.
Date:       20/09/2019

To run the python script, following parameters need to pass
 $1   - Host name of WebLogic admin server console
 $2   - Port number of WebLogic admin server console
 $3   - User name to access WebLogic admin server console ui
 $4   - Password to access WebLogic admin server console ui

*****************************************************************************
"""

"""
 This method returns the WebLogic server's status string from status code.
"""
def getHealthStateTxt(healthState):
  switcher = {
    0: "OK",
    1: "WARN",
    2: "CRITICAL",
    3: "FAILED",
    4: "OVERLOADED"
  }
  return switcher.get(healthState, "UNKNOWN")

"""
 This method returns the server state details.
"""
def serverStatus(server):
  cd('/ServerLifeCycleRuntimes/')
  cd(server)
  return cmo.getState()

"""
 This method returns the server list from the configured domain.
"""
def getServerNames():
  domainConfig()
  return cmo.getServers()

""" 
 This method connect the WebLogic admin server console.
"""
def conn():
  try:
    admin_addr = str(sys.argv[1])
    admin_port = str(sys.argv[2])
    user = str(sys.argv[3])
    pwd = str(sys.argv[4])
    serverPath = 't3://'+admin_addr+':'+admin_port
    connect(user, pwd, serverPath)
    #serverNames = cmo.getServers()
  except:
    print 'Admin server not in running state....'

"""
 This method prints the admin and all associated managed server details.
 Also prints the list applications deployed in the servers.
"""
def printServerAndAppDetails():
  domainRuntime()
  count=0
  print 'All Deployed Elements Details'
  print '-----------------------------'
  cd('AppRuntimeStateRuntime/AppRuntimeStateRuntime')
  appList = cmo.getApplicationIds()
  if len(appList) == 0:
    print 'No application(s) deployed in server'
  for app in appList:
    if count == 0:
       print "%-8s %-40s %-20s" % ("Sl No#","Deployed Application Name","Application State")
       print '---------------------------------------------------------------------'
    count+=1
    appState=cmo.getIntendedState(app)
    print "%-8s %-40s %-20s" % (str(count),str(app),str(appState))

  count=0
  print '\n'
  print 'Admin and Managed Servers Health Details'
  print '----------------------------------------'
  cd('ServerRuntimes')
  serverList=domainRuntimeService.getServerRuntimes()
  if len(serverList) == 0:
    print 'Server details not found'
  for server in serverList:
    if count == 0:
       print "%-8s %-30s %-10s %-10s %-20s %-20s" % ("Sl No#","Server Name","State","Health","Listen Port","Listen Address")
       print '-------------------------------------------------------------------------------------------------------------'
    count+=1
    try:
       healthStateTxt=getHealthStateTxt(server.getHealthState().getState())
       print "%-8s %-30s %-10s %-10s %-20s %-20s" % (str(count),str(server.getName()),str(server.getState()),str(healthStateTxt),str(server.getListenPort()),str(server.getListenAddress()))
    except Exception, inst:
       print "Exception getting server details" +server.getName()
       print inst.value

"""
 This method prints the data source details which were configured in WebLogic admin/managed servers.
"""
def printDataSourceDetails():

  flag=false
  count=0
  print '\n'
  print 'DataSource Details'
  print '------------------'

  try:
    serverList=domainRuntimeService.getServerRuntimes();
    for server in serverList:
       svrname=server.getName();
       jdbcruntime=server.getJDBCServiceRuntime();
       dsList=jdbcruntime.getJDBCDataSourceRuntimeMBeans();
       if len(dsList) > 0:
          flag=true
       for ds in dsList:
          if count == 0:
             print "%-8s %-25s %-25s %-15s %-15s %-15s %-15s %-15s %-15s %-15s" % ("Sl No#","DataSource","DataSource","State","Number","Total Leaked","Current","Connection","Total Active","Total Waiting")
             print "%-8s %-25s %-25s %-15s %-15s %-15s %-15s %-15s %-15s %-15s" % ("","For","Name","","Available","Connection","Capacity","Delay Time","Connections","For Connection")
             print '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
          count+=1;
          print "%-8s %-25s %-25s %-15s %-15s %-15s %-15s %-15s %-15s %-15s" % (str(count),str(svrname),str(ds.getName()),str(ds.getState()),str(ds.getNumAvailable()),str(ds.getLeakedConnectionCount()),str(ds.getCurrCapacity()),str(ds.getConnectionDelayTime()),str(ds.getActiveConnectionsCurrentCount()),str(ds.getWaitingForConnectionCurrentCount()))
    if len(serverList) == 0 or flag == false:
       print 'Datasource details not found'

  except Exception, inst:
    print "Exception getting server details" +server.getName()
    print inst.value

"""
 This method prints the jms modules details which were configured in WebLogic admin/managed servers.
"""
def printJMSModulesDetails():
  flag=false
  count=0
  print '\n'
  print 'JMS Modules Details (Excluding Foreign Server Configuration)'
  print '------------------------------------------------------------'

  try:
    serverList=domainRuntimeService.getServerRuntimes();
    for server in serverList:
       svrname=server.getName();
       jmsRuntime = server.getJMSRuntime();
       jmsList = jmsRuntime.getJMSServers();
       if len(jmsList) > 0:
          flag=true
       for jmsServer in jmsList:
          destinationList = jmsServer.getDestinations();
	  for destination in destinationList:
             moduleName = '-'
             name = '-'
	     if count == 0:
                print "%-8s %-25s %-40s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s" % ("Sl No#","JMS","Name","Messages","Messages","Messages","Messages","Consumers","Consumers","Consumers","Bytes")
                print "%-8s %-25s %-40s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s" % ("","Modules","","Current","High","Pending","Total","Current","High","Total","Current")
                print '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
             count+=1;
             dstName=str(destination.getName())
             if dstName.find('!') != -1:
                moduleName = dstName[0:dstName.find('!')];
                name = dstName[dstName.find('!')+1::];
             print "%-8s %-25s %-40s %-15s %-15s %-15s %-15s %-15s %-15s %-15s %-15s" % (str(count),moduleName,name,str(destination.getMessagesCurrentCount()),str(destination.getMessagesHighCount()),str(destination.getMessagesPendingCount()),str(destination.getMessagesReceivedCount()),str(destination.getConsumersCurrentCount()),str(destination.getConsumersHighCount()),str(destination.getConsumersTotalCount()),str(destination.getBytesCurrentCount()))
    if len(serverList) == 0 or flag == false:
       print 'JMS modules details not found'

  except Exception, inst:
    print "Exception getting server details" +server.getName()
    print inst.value


if __name__== "main":
  redirect('/dev/null', 'false')
  conn()
  printServerAndAppDetails()
  printDataSourceDetails()
  printJMSModulesDetails()
  disconnect()
  exit()
