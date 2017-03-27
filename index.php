<html>
   <header>
     <title>Network Virtual Appliance</title>
   </header>
   <body>
     <h1>
       Welcome to the Open Source Azure Networking Lab
     </h1>
     <br>
     <?php
       $hosts = array ("bing.com", "1.2.3.4", "10.4.2.101");
       $allReachable = true;
       foreach ($hosts as $host) {
         $result = exec ("ping -c 1 -W 1 " . $host . " 2>&1 | grep received");
         $pos = strpos ($result, "1 received");
         if ($pos === false) {
           $allReachable = false;
           break;
         }
       }
       if ($allReachable === false) {
         // Ping did not work
         http_response_code (202);
         print ("The target hosts do not seem to be all reachable (" . $host . ")\n");
       } else {
         // Ping did work
         http_response_code (201);
         print ("All target hosts seem to be reachable");
       }
     ?>
   </body>
</html>
