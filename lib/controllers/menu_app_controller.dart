import 'package:flutter/material.dart';
import '../../responsive.dart';

class MenuAppController extends ChangeNotifier {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isLargeScreen = false;
  bool _isDrawerOpen = false;
  bool isPopupOpen = false;

  GlobalKey<ScaffoldState> get scaffoldKey => _scaffoldKey;

  bool get isDrawerOpen => _isDrawerOpen;

  MenuAppController();

  void controlMenu() {
    _isDrawerOpen = !_isDrawerOpen;
    notifyListeners();
  }

  void setLargeScreen(bool value) {
    if (isLargeScreen != value) {
      isLargeScreen = value;
      notifyListeners();
    }
  }

  void updateScreenSize(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setLargeScreen(Responsive.isDesktop(context));
    });
  }

  void togglePopup() {
    isPopupOpen = !isPopupOpen;
    notifyListeners();
  }

  void closePopup() {
    isPopupOpen = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _scaffoldKey.currentState?.dispose();
    super.dispose();
  }
}
