#'	Used to remove directory and its content
#' @param folder Character. Path to folder.
#' @noRd
rmfolder <- function(folder) {
  lapply(list.files(folder, full.names=TRUE), file.remove)
  file.remove(folder)
}

#' Used to check if a url is valid
#' @param url Character. URL.
#' @param timeout Integer. Seconds before timeout.
#' @param quiet Boolean. Whether to display output.
#' @param test_url Boolean. Whether to test if the url connects or not. FALSE by default (can take a while).
#' @importFrom httr RETRY
#' @noRd
valid_url <- function(url, timeout = 5, test_url = TRUE, quiet = TRUE) {

	stopifnot(is.character(url))

	connecting <- function(url) {
		r <- base::try({
		    httr::RETRY(
		        verb = "GET"
		        , url = url
		        , timeout = timeout
		        , silent = TRUE
		        , times = 5
		        , terminate_on = c(403, 404)
		        , terminate_on_success = TRUE
		    )
		})
		if(!assertthat::is.error(r)) {
			r$status_code == 200
		} else {
			if(!quiet) message("Timeout.")
			return(FALSE)
		}
	}

	url_cond1 <- grepl('http[s]?://.*', url) # valid zip file

	# if valid zip file, test to see if anything connects
	if(test_url) {
		if(url_cond1) url_cond2 <- connecting(url) else url_cond2 <- FALSE
	} else url_cond2 <- NULL

	if(!quiet & test_url) {
		message(sprintf("Validating '%s'...", url))
		if(all(c(url_cond2, url_cond1))) message("PASS") else message("FAIL")
	}

	return(all(url_cond1, url_cond2))
}

#' Used to trigger suppressWarnings or not
#' @param expr expression to suppress
#' @param quiet Logical. Whether to suppress or not. \code{FALSE} by default.
#' @noRd
trigger_suppressWarnings <- function(expr, quiet) {

	if(!quiet) expr else suppressWarnings(expr)

}

#' Writes a gtfs object to a zip file. Calculated tidytransit tables and columns are not exported.
#' @param gtfs_obj a gtfs feed object
#' @param zipfile path to the zip file the feed should be written to
#' @param compression_level a number between 1 and 9.9, passed to zip::zip
#' @importFrom zip zipr
#' @export
write_gtfs <- function(gtfs_obj, zipfile, compression_level = 9) {
  stopifnot(is_gtfs_obj(gtfs_obj))

  meta <- get_gtfs_meta()
  dir.create(tmp <- tempfile())
  filenames = names(gtfs_obj)
  filenames <- filenames[filenames != "."]

  for(filename in filenames) {
    dd <- as.data.frame(gtfs_obj[[filename]])

    # formate dates yyyymmdd
    colclasses <- sapply(dd, class)
    date_cols <- which(colclasses == "Date")
    dd[date_cols] <- format(dd[date_cols], "%Y%m%d")

    # remove columns from set_hms_times
    cn <- colnames(dd)[which(!(colnames(dd) %in% c("arrival_time_hms", "departure_time_hms", "start_time_hms", "end_time_hms")))]
    dd <- dd[cn]

    readr::write_csv(dd, paste0(tmp, "/", filename, ".txt"), )
  }
  filelist = paste0(tmp, "/", filenames, ".txt")
  zip::zipr(zipfile, filelist, recurse = F, compression_level = compression_level)
}

#' Returns TRUE if the given gtfs_obj contains the table. Used to check for
#' tidytransit's calculated tables in sublist
#' @param gtfs_obj gtfs object
#' @param table_name name as string of the table to look for
feed_contains <- function(gtfs_obj, table_name) {
  exists(table_name, where = gtfs_obj) ||
    (exists(".", where = gtfs_obj) && exists(table_name, where = gtfs_obj$.))
}
