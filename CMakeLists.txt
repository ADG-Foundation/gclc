cmake_minimum_required(VERSION 3.13 FATAL_ERROR)
project(GCLC LANGUAGES CXX)

include(GNUInstallDirs)

set(gui AUTO CACHE STRING "build the GCLC GUI")
set_property(CACHE gui PROPERTY STRINGS AUTO ON OFF)

# enable -W and -Wall if possible
include(CheckCXXCompilerFlag)
CHECK_CXX_COMPILER_FLAG(-W HAS_W)
if(HAS_W)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -W")
endif()
CHECK_CXX_COMPILER_FLAG(-Wall HAS_WALL)
if(HAS_WALL)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall")
endif()
CHECK_CXX_COMPILER_FLAG(-Wmissing-declarations HAS_WMISSING_DECLARATIONS)
if(HAS_WMISSING_DECLARATIONS)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wmissing-declarations")
endif()
CHECK_CXX_COMPILER_FLAG(-Wcast-qual HAS_WCAST_QUAL)
if(HAS_WCAST_QUAL)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wcast-qual")
endif()

if(NOT gui STREQUAL "OFF")
  find_package(Qt6 COMPONENTS Core Gui PrintSupport Widgets)
  if(gui STREQUAL "AUTO")
    if(Qt6_FOUND)
      message(STATUS "setting -Dgui=ON")
      set(gui ON)
    else()
      message(STATUS "setting -Dgui=OFF")
      set(gui OFF)
    endif()
  elseif(NOT Qt6_FOUND)
    message(FATAL_ERROR "-Dgui=ON and Qt6 not found")
  endif()
endif()

add_executable(gclc
  source/cGCLCmain.cpp
  source/Export/TikZOutput.cpp
  source/Export/SVGOutput.cpp
  source/Export/PSTricksOutput.cpp
  source/Export/LaTeXOutput.cpp
  source/Export/GCLCOutput.cpp
  source/Export/EPSOutput.cpp
  source/ExpressionParser/parser.cpp
  source/GCLCEngine/Transformations.cpp
  source/GCLCEngine/TheoremProving.cpp
  source/GCLCEngine/LowLevelCommands.cpp
  source/GCLCEngine/Layers.cpp
  source/GCLCEngine/LabelingCommands.cpp
  source/GCLCEngine/GCLC.cpp
  source/GCLCEngine/DrawingCommands.cpp
  source/GCLCEngine/Cartesian3DCommands.cpp
  source/GCLCEngine/Cartesian2DCommands.cpp
  source/GCLCEngine/Calculations.cpp
  source/GCLCEngine/BasicDefinitions.cpp
  source/GCLCEngine/BasicConstructions.cpp
  source/GCLCEngine/Animations.cpp
  source/GenericEngine/IntermediateRepresentation.cpp
  source/GenericEngine/GCompiler.cpp
  source/GraphDrawing/settings.cpp
  source/GraphDrawing/graph_util.cpp
  source/GraphDrawing/graphnode.cpp
  source/GraphDrawing/graph.cpp
  source/GraphDrawing/drawing.cpp
  source/GraphDrawing/barycenterdrawing.cpp
  source/GraphDrawing/arclayereddrawing.cpp
  source/Input/StringInput.cpp
  source/Input/GCLCInput.cpp
  source/Input/FileInput.cpp
  source/Logging/GCLCLog.cpp
  source/Logging/FileLog.cpp
  source/Logging/DummyLog.cpp
  source/Utils/Utils.cpp
  source/Utils/Timer.cpp
  source/TheoremProver/WuMethod.cpp
  source/TheoremProver/TheoremProver.cpp
  source/TheoremProver/ProverExpression.cpp
  source/TheoremProver/GroebnerMethod.cpp
  source/TheoremProver/AreaMethod.cpp
  source/TheoremProver/AlgMethodReducible.cpp
  source/TheoremProver/AlgMethod.cpp
  source/AlgebraicMethods/XTerm.cpp
  source/AlgebraicMethods/xpolynomial.cpp
  source/AlgebraicMethods/Wu.cpp
  source/AlgebraicMethods/UTerm.cpp
  source/AlgebraicMethods/UPolynomialFraction.cpp
  source/AlgebraicMethods/UPolynomial.cpp
  source/AlgebraicMethods/TermStorageVector.cpp
  source/AlgebraicMethods/TermStorageAvl.cpp
  source/AlgebraicMethods/TermStorage.cpp
  source/AlgebraicMethods/Term.cpp
  source/AlgebraicMethods/Reduce.cpp
  source/AlgebraicMethods/Prover.cpp
  source/AlgebraicMethods/Power.cpp
  source/AlgebraicMethods/PolyReader.cpp
  source/AlgebraicMethods/Polynomial.cpp
  source/AlgebraicMethods/Object.cpp
  source/AlgebraicMethods/Log.cpp
  source/AlgebraicMethods/ITimeOut.cpp
  source/AlgebraicMethods/Groebner.cpp
  source/Import/ListOfFaces.cpp 
)

# Update ISO to C++17
target_compile_features(gclc PRIVATE cxx_std_17)

install(TARGETS gclc
        DESTINATION ${CMAKE_INSTALL_BINDIR}
)

add_subdirectory(source)


# CPack
if(NOT CPACK_PACKAGE_VERSION)
  set(CPACK_PACKAGE_VERSION "2024.1.0")
endif()

set(CPACK_PACKAGE_NAME "gclc")
set(CPACK_PACKAGE_VENDOR "ADG Foundation")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Geometry Constructions -> LaTeX Converter and theorem prover")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/ADG-Foundation/gclc")
set(CPACK_PACKAGE_CONTACT "TODO: add")
#set(CPACK_PACKAGE_CONTACT "Predrag Janicic <janicic@matf.bg.ac.rs>")

# 2. Debian (.deb) Settings
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")
set(CPACK_DEBIAN_PACKAGE_SECTION "math")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")

# Automatically scans ELF binaries for libc, libstdc++, and Qt6 library deps
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)

# Explicitly add runtime plugins that are loaded via dlopen()
set(CPACK_DEBIAN_PACKAGE_DEPENDS "qt6-qpa-plugins, libxcb-cursor0")

# 3. RPM (.rpm) Settings
set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_RPM_PACKAGE_GROUP "Applications/Engineering")
set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")

# Automatically scans symbols/sonames for glibc and Qt6 library requirements
set(CPACK_RPM_PACKAGE_AUTOREQPROV ON)

# Explicitly add runtime plugins that are loaded via dlopen()
set(CPACK_RPM_PACKAGE_REQUIRES "qt6-qtbase-gui")

# 4. Include CPack (Must remain at the very end of the file)
include(CPack)