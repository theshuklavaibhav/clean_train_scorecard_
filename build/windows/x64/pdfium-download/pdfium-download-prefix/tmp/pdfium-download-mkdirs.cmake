# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "C:/Users/Vaibhav/Downloads/InternApps/Railway_Scorecard_App/build/windows/x64/pdfium-src"
  "C:/Users/Vaibhav/Downloads/InternApps/Railway_Scorecard_App/build/windows/x64/pdfium-build"
  "C:/Users/Vaibhav/Downloads/InternApps/Railway_Scorecard_App/build/windows/x64/pdfium-download/pdfium-download-prefix"
  "C:/Users/Vaibhav/Downloads/InternApps/Railway_Scorecard_App/build/windows/x64/pdfium-download/pdfium-download-prefix/tmp"
  "C:/Users/Vaibhav/Downloads/InternApps/Railway_Scorecard_App/build/windows/x64/pdfium-download/pdfium-download-prefix/src/pdfium-download-stamp"
  "C:/Users/Vaibhav/Downloads/InternApps/Railway_Scorecard_App/build/windows/x64/pdfium-download/pdfium-download-prefix/src"
  "C:/Users/Vaibhav/Downloads/InternApps/Railway_Scorecard_App/build/windows/x64/pdfium-download/pdfium-download-prefix/src/pdfium-download-stamp"
)

set(configSubDirs Debug;Release;MinSizeRel;RelWithDebInfo)
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "C:/Users/Vaibhav/Downloads/InternApps/Railway_Scorecard_App/build/windows/x64/pdfium-download/pdfium-download-prefix/src/pdfium-download-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "C:/Users/Vaibhav/Downloads/InternApps/Railway_Scorecard_App/build/windows/x64/pdfium-download/pdfium-download-prefix/src/pdfium-download-stamp${cfgdir}") # cfgdir has leading slash
endif()
