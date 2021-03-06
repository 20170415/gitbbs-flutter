import 'package:fish_redux/fish_redux.dart';
import 'package:flutter/material.dart';
import 'package:gitbbs/constant/AssetsConstant.dart';
import 'package:gitbbs/constant/ColorConstant.dart';
import 'package:gitbbs/ui/login/action.dart';
import 'package:gitbbs/ui/login/state.dart';

Widget buildView(
    LoginPageState state, Dispatch dispatch, ViewService viewService) {
  return Scaffold(
    key: state.scaffoldKey,
    appBar: AppBar(
      title: Text('登录'),
    ),
    body: Builder(builder: (context) {
      return SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(left: 40, top: 60, right: 40, bottom: 20),
          child: Column(
            children: <Widget>[
              Center(
                child: Image.asset(
                  ic_github,
                  width: 100,
                ),
              ),
              Padding(padding: EdgeInsets.fromLTRB(0, 10, 0, 10)),
              _formBuild(state, dispatch, viewService),
              Padding(padding: EdgeInsets.fromLTRB(0, 10, 0, 10)),
              _buttonBuild(state, dispatch, viewService),
              Padding(padding: EdgeInsets.fromLTRB(0, 10, 0, 10)),
              _checkboxBuild(state, dispatch, viewService),
            ],
          ),
        ),
      );
    }),
  );
}

_checkboxBuild(
    LoginPageState state, Dispatch dispatch, ViewService viewService) {
  return Column(
    children: <Widget>[
      CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: state.starDataRepo,
        onChanged: (changed) {
          dispatch(
              LoginActionCreator.onStarDataRepoCheckChangedAction(changed));
        },
        title: Text('登录成功后star数据源仓库'),
      ),
      CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: state.starAppRepo,
        onChanged: (changed) {
          dispatch(LoginActionCreator.onStarAppRepoCheckChangedAction(changed));
        },
        title: Text('支持开发star源码仓库'),
      ),
    ],
  );
}

_formBuild(LoginPageState state, Dispatch dispatch, ViewService viewService) {
  return Form(
      key: state.formKey,
      child: Column(
        children: <Widget>[
          TextField(
            decoration: InputDecoration(
                contentPadding: EdgeInsets.all(10), labelText: 'GITHUB用户名'),
            controller: state.usernameController,
          ),
          TextField(
            decoration: InputDecoration(
                contentPadding: EdgeInsets.all(10), labelText: '登录密码'),
            controller: state.passwordController,
            obscureText: true,
          )
        ],
      ));
}

_buttonBuild(LoginPageState state, Dispatch dispatch, ViewService viewService) {
  return Row(
    children: <Widget>[
      Expanded(
          child: RaisedButton(
        onPressed: () {
          dispatch(LoginActionCreator.loginAction());
        },
        color: app_primary,
        textColor: Colors.white,
        child: state.loading
            ? Container(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text('登录'),
      ))
    ],
  );
}
