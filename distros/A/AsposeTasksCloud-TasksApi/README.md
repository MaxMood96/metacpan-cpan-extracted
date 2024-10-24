##Aspose.Tasks Cloud SDK for Perl

This repository contains Aspose.Tasks Cloud SDK for Perl source code. This SDK allows you to work with Aspose.Tasks Cloud REST APIs in your perl applications quickly and easily. 

<p align="center">
  <a title="Download complete Aspose.Tasks for Cloud source code" href="https://github.com/asposetasks/Aspose_tasks_Cloud/archive/master.zip">
	<img src="https://raw.github.com/AsposeExamples/java-examples-dashboard/master/images/downloadZip-Button-Large.png" />
  </a>
</p>

##How to Use the SDK?
The complete source code is available in this repository folder. For more details, please visit our [documentation website](http://www.aspose.com/docs/display/taskscloud/Available+SDKs).

##Quick SDK Tutorial
```javascript
use lib 'lib';
use strict;
use warnings;
use File::Slurp; # From CPAN

use AsposeStorageCloud::StorageApi;
use AsposeStorageCloud::ApiClient;
use AsposeStorageCloud::Configuration;

use AsposeTasksCloud::TasksApi;
use AsposeTasksCloud::ApiClient;
use AsposeTasksCloud::Configuration;

$AsposeTasksCloud::Configuration::app_sid = 'XXX';
$AsposeTasksCloud::Configuration::api_key = 'XXX';

$AsposeTasksCloud::Configuration::debug = 1;
$AsposeStorageCloud::Configuration::app_sid = $AsposeTasksCloud::Configuration::app_sid;
$AsposeStorageCloud::Configuration::api_key = $AsposeTasksCloud::Configuration::api_key;

#Instantiate Aspose.Storage API SDK 
my $storageApi = AsposeStorageCloud::StorageApi->new();

#Instantiate Aspose.Tasks API SDK
my $tasksApi = AsposeTasksCloud::TasksApi->new();

my $data_path = '../data/';

#set input file name
my $filename = 'sample-project';
my $name = $filename . '.mpp';
my $format = "pdf";

#upload file to aspose cloud storage 
my $response = $storageApi->PutCreate(Path => $name, file => $data_path.$name);

#invoke Aspose.Tasks Cloud SDK API to convert project document to other formats                                   
$response = $tasksApi->GetTaskDocumentWithFormat(name => $name, format => $format);

if($response->{'Status'} eq 'OK'){
	#save converted format file from response stream
    my $output_file = 'C:/temp/'. $filename . '.' . $format;
	write_file($output_file, { binmode => ":raw" }, $response->{'Content'});
}

```javascript
##Contact Us
Your feedback is very important to us. Please feel free to contact us using our [Support Forums](https://www.aspose.com/community/forums/)
