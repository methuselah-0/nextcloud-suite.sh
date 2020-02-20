<?php
function httpCheckAbuse($ip){
    $key="[secret API key]";
    $url = "https://www.abuseipdb.com/check/".$ip."/json";
    $ret=httpRequest($url,'GET',['key'=>$key,'days'=>60],$status);

    if ($status==200)
        return json_decode($ret);
    else
        return false;
}
function httpReportAbuse($ip,$comment){
    $key="[secret API key]";
    $url = "https://www.abuseipdb.com/report/json";

    $ret=httpRequest($url,'GET',
        [
	    'key'=>$key,
	    'category'=>10,
	    'comment'=>$comment,
	    'ip'=>$ip,
	],$status);
    if ($status==200)
        return json_decode($ret);
    else
        return false;


function httpRequest($url,$method,$queryArray,&$status=null){
    $request = curl_init();
        // Set request options
	    try{
	            switch ($method){
		                case 'POST':
				                curl_setopt_array($request, array
						                    (
								                            CURLOPT_URL => $url,
											                            CURLOPT_POST => true,
														                            CURLOPT_POSTFIELDS => http_build_query($queryArray),
																	                        ));
																				                break;
																						            case 'GET':
																							                default:
																									                curl_setopt_array($request, array
																											                    (
																													                            CURLOPT_URL => $url."?".http_build_query($queryArray),
																																                        ));
																																			        }

        curl_setopt($request,CURLOPT_RETURNTRANSFER , true);
	        curl_setopt($request,CURLOPT_HEADER, false);
		        // Execute request and get response and status code
			        $response = curl_exec($request);
				        $status = curl_getinfo($request, CURLINFO_HTTP_CODE);

        curl_close($request);
	        if($status == 200)
		            return $response;
			        }catch (Exception $ex){
				        return null;
					    }
					        return null;
						}