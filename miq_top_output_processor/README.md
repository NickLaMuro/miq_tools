`miq_top_output_processor`
==========================

Used to process through the `top_output` files from an appliance dump and
define a `gnuplot` readable file that can track the memory usage of a given
process type.


Usage
-----

Given you have a tar of the extracted log files from an appliance:

1. Untar the needed files from the log tarball.  If it is compressed using
   gzip, then you can used the following command:
   
   ```console
   $ tar -xzf [ARCHIVE_TO_BE_OPENED] log/top_output/*
   ```
   
   If the tar is compressed using `xz`, and you have a older version of `tar`
   without `xz` support, than you might have to unpack the files using the
   following:
   
   ```console
   $ unxz -c [ARCHIVE_TO_BE_OPENED] | tar -xf - log/top_output/*
   ```
   
2. Run the script, specifying the files in order that you want to read from.
   Most likely something like this:
   
   ```console
   $ ruby top_processor.rb --worker-type="MIQ Server" log/top_output.log-* log/top_output.log
   ```
   
   Ideally, you want to use the `--worker-type` flag to make sure you are only
   capturing top info from the specific process type you are interested in.
   PID specific files will created in the `top_outputs/` directory, named with
   the datestamp of when the pid first appeared, and the pid, with an extension
   of `.data`.
   
3. [Optional] To plot the collected data, you can use the included
   `top_info_plot.gnup` command to plot the data you have collected.  To plot
   everything, find one of the output files from above and run:
   
   ```console
   top_info_plot.gnup top_outputs/[TIMESTAMP]_[PID].data
   ```
   
   The plot will output a PNG in the same directory and file name as the input
   file, just with the ext changed from `.data` to `.png`.  If you wish to
   select a subset of the time data, you can provide timestamps to the command
   as well. 
   
   ```console
   top_info_plot.gnup top_outputs/[TIMESTAMP]_[PID].data 2000-01-01T00:00:00 2000-01-02T00:00:00 
   ```
