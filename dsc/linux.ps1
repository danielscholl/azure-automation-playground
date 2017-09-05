Configuration ExampleConfiguration{

    Import-DscResource -Module nx

    Node  "localhost"{
        nxFile ExampleFile {

            DestinationPath = "/tmp/example"
            Contents = "hello world `n"
            Ensure = "Present"
            Type = "File"
        }
    }
}