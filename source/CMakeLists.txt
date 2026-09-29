if(gui)

  add_executable(gclc-gui
    gGCLCmain.cpp
    Export/TikZOutput.cpp
    Export/SVGOutput.cpp
    Export/PSTricksOutput.cpp
    Export/LaTeXOutput.cpp
    Export/GCLCOutput.cpp
    Export/EPSOutput.cpp
    ExpressionParser/parser.cpp
    GCLCEngine/Transformations.cpp
    GCLCEngine/TheoremProving.cpp
    GCLCEngine/LowLevelCommands.cpp
    GCLCEngine/Layers.cpp
    GCLCEngine/LabelingCommands.cpp
    GCLCEngine/GCLC.cpp
    GCLCEngine/DrawingCommands.cpp
    GCLCEngine/Cartesian3DCommands.cpp
    GCLCEngine/Cartesian2DCommands.cpp
    GCLCEngine/Calculations.cpp
    GCLCEngine/BasicDefinitions.cpp
    GCLCEngine/BasicConstructions.cpp
    GCLCEngine/Animations.cpp
    GenericEngine/GCompiler.cpp
    GraphDrawing/settings.cpp
    GraphDrawing/graph_util.cpp
    GraphDrawing/graphnode.cpp
    GraphDrawing/graph.cpp
    GraphDrawing/drawing.cpp
    GraphDrawing/barycenterdrawing.cpp
    GraphDrawing/arclayereddrawing.cpp
    Input/StringInput.cpp
    Input/GCLCInput.cpp
    Input/FileInput.cpp
    Logging/GCLCLog.cpp
    Logging/FileLog.cpp
    Logging/DummyLog.cpp
    Utils/Utils.cpp
    Utils/Timer.cpp
    TheoremProver/WuMethod.cpp
    TheoremProver/TheoremProver.cpp
    TheoremProver/ProverExpression.cpp
    TheoremProver/GroebnerMethod.cpp
    TheoremProver/AreaMethod.cpp
    TheoremProver/AlgMethodReducible.cpp
    TheoremProver/AlgMethod.cpp
    AlgebraicMethods/XTerm.cpp
    AlgebraicMethods/xpolynomial.cpp
    AlgebraicMethods/Wu.cpp
    AlgebraicMethods/UTerm.cpp
    AlgebraicMethods/UPolynomialFraction.cpp
    AlgebraicMethods/UPolynomial.cpp
    AlgebraicMethods/TermStorageVector.cpp
    AlgebraicMethods/TermStorageAvl.cpp
    AlgebraicMethods/TermStorage.cpp
    AlgebraicMethods/Term.cpp
    AlgebraicMethods/Reduce.cpp
    AlgebraicMethods/Prover.cpp
    AlgebraicMethods/Power.cpp
    AlgebraicMethods/PolyReader.cpp
    AlgebraicMethods/Polynomial.cpp
    AlgebraicMethods/Object.cpp
    AlgebraicMethods/Log.cpp
    AlgebraicMethods/ITimeOut.cpp
    AlgebraicMethods/Groebner.cpp
    Input/EditorInput.cpp
    Export/QGraphicsViewOutput.cpp
    Logging/QOutputLog.cpp
    Import/JavaView.cpp
    Import/ListOfFaces.cpp
    GUI/FreePointItem.cpp
    GUI/FindDialog.cpp
    GUI/ReplaceDialog.cpp
    GUI/ChildWindow.cpp
    GUI/MainWindow.cpp
    GUI/ExportToRasterFormat.cpp
    GUI/WatchWindow.cpp
    GUI/ChildForm.cpp
    GUI/Highlighter.cpp
    GUI/OutputHighlighter.cpp
    GenericEngine/IntermediateRepresentation.cpp
    resource.qrc
  )

  set_target_properties(gclc-gui PROPERTIES
    AUTOMOC ON
    AUTORCC ON
    AUTOUIC ON
    AUTOUIC_SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR}/GUI"
  )

  # require ISO C++17
  target_compile_features(gclc-gui PRIVATE cxx_std_17)

  target_include_directories(gclc-gui PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

  target_link_libraries(gclc-gui
    PRIVATE Qt6::Core Qt6::Gui Qt6::PrintSupport Qt6::Widgets)

  install(TARGETS gclc-gui
          DESTINATION ${CMAKE_INSTALL_BINDIR}
  )

  # install desktop integration
  set(GCLC_APP_ID "io.github.ADG_Foundation.gclc")

  install(FILES "../flatpak/${GCLC_APP_ID}.desktop"
          DESTINATION "${CMAKE_INSTALL_DATADIR}/applications"
  )

  install(FILES "../flatpak/${GCLC_APP_ID}.metainfo.xml"
          DESTINATION "${CMAKE_INSTALL_DATADIR}/metainfo"
  )

  set(ICON_RESOLUTIONS "32;64;128;256;512")
  foreach(RES IN LISTS ICON_RESOLUTIONS)
    install(FILES "../flatpak/icon/${RES}.png"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor/${RES}x${RES}/apps"
            RENAME "${GCLC_APP_ID}.png"
    )
  endforeach ()

  if(WIN32)
    target_sources(gclc-gui PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/gclc.rc")
    target_include_directories(gclc-gui PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

endif()
