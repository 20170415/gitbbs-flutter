import 'dart:convert';

import 'package:gitbbs/constant/GitConstant.dart';
import 'package:gitbbs/model/GitIssue.dart';
import 'package:gitbbs/model/GitUser.dart';
import 'package:gitbbs/model/PagingData.dart';
import 'package:gitbbs/model/cachemanager/user_cache_manager.dart';
import 'package:gitbbs/model/db/gitissue_data_base.dart';
import 'package:gitbbs/model/git_comment.dart';
import 'package:gitbbs/model/cachemanager/git_gist_cache_manager.dart';
import 'package:gitbbs/model/git_content_file.dart';
import 'package:gitbbs/network/github/model/github_content_file.dart';
import 'package:gitbbs/network/github/model/github_gist.dart';
import 'package:gitbbs/network/github/model/github_gist_file.dart';
import 'package:gitbbs/model/cachemanager/issue_cache_manager.dart';
import 'package:gitbbs/network/GitHttpClient.dart';
import 'package:gitbbs/network/GitNetworkRequestAdapter.dart';
import 'package:gitbbs/network/IssueState.dart';
import 'package:gitbbs/network/github/model/GithubComment.dart';
import 'package:gitbbs/network/github/model/GithubUser.dart';
import 'package:gitbbs/network/github/model/GithubV4Issue.dart';
import 'package:gitbbs/network/github/model/github_message.dart';
import 'package:gitbbs/network/github/model/label_info.dart';
import 'package:gitbbs/network/github/v4/GithubV4NetWorkAdapter.dart';
import 'package:gitbbs/network/github/v4/v4_convert.dart';
import '../GitHttpRequest.dart';
import 'GithubApi.dart';

class GithubHttpRequest implements GitHttpRequest {
  GitHttpClient _client;
  GitNetworkRequestAdapter _adapter;
  static GithubHttpRequest _instance = GithubHttpRequest();
  static String configGistId = '';

  GithubHttpRequest() {
    _adapter = GithubV4NetWorkAdapter();
    _client = GitHttpClient(_adapter.getApiUrl());
  }

  static getInstance() {
    return _instance;
  }

  @override
  Future<PagingData<GitIssue>> getMoreIssues(
      {List<String> label,
      String creator,
      IssueState state,
      String before,
      String after}) async {
    final size = 15;
    var response = await _client.execute(
        _adapter.getMoreIssues(label, creator, state, before, after, size));
    var issues = List<GitIssue>();
    List list = response.data['data']['repository']['issues']['edges'];
    list.forEach((map) {
      GithubV4Issue issue = V4Convert.toIssue(map['node']);
      issue.cursor = map['cursor'];
      issues.add(issue);
    });
    GitIssueDataBase.createInstance().saveAll(issues);
    return PagingData(issues.length == size, issues);
  }

  @override
  Future<PagingData<GitComment>> getComments(int number, String before) async {
    final size = 15;
    var response =
        await _client.execute(_adapter.getComments(number, before, size));
    List list =
        response.data['data']['repository']['issue']['comments']['edges'];
    var comments = list.map<GithubComment>((map) {
      var comment = V4Convert.toComment(map['node']);
      comment.cursor = map['cursor'];
      return comment;
    }).toList();
    var data = PagingData(comments.length == size, comments);
    if (before == null || before == '') {
      IssueCacheManager.saveIssueComments(number, data);
    }
    return data;
  }

  @override
  getIssue(int number) async {
    var response = await _client.execute(_adapter.getIssue(number));
    if (response.data.containsKey('errors')) {
      await IssueCacheManager.deleteIssueCache(number);
      await GitIssueDataBase.createInstance().deleteByNumber(number);
      return null;
    }
    Map map = response.data['data']['repository']['issue'];
    var issue = V4Convert.toIssue(map);
    try {
      IssueCacheManager.saveIssueCache(issue.getNumber(), issue.body);
      GitIssueDataBase.createInstance().save(issue, updateBrowseDate: true);
    } catch (e) {}
    return issue;
  }

  @override
  Future<GitComment> addComment(String issueId, String body) async {
    var response = await _client.execute(_adapter.addComment(issueId, body));
    Map data = response.data;
    if (data.containsKey('errors')) {
      return null;
    }
    Map map = response.data['data']['addComment']['commentEdge'];
    var comment = V4Convert.toComment(map['node']);
    comment.cursor = map['cursor'];
    return comment;
  }

  @override
  Future<bool> modifyComment(String commentId, String body) async {
    var response =
        await _client.execute(_adapter.modifyComment(commentId, body));
    Map data = response.data;
    if (data.containsKey('errors')) {
      return false;
    }
    return true;
  }

  @override
  Future<bool> deleteComment(String commentId) async {
    var response = await _client.execute(_adapter.deleteComment(commentId));
    Map data = response.data;
    if (data.containsKey('errors')) {
      return false;
    }
    return true;
  }

  Future<GithubGist> getFavoriteGist() async {
    var response = await _client
        .execute(_adapter.getGists(UserCacheManager.getUser().getName()));
    Map data = response.data;
    if (data.containsKey('errors')) {
      return null;
    }
    List list = data['data']['user']['gists']['nodes'];
    GithubGist gist = _getFavoriteGist(list);
    if (gist != null) {
      UserCacheManager.saveFavoriteGist(gist);
    }
    return gist;
  }

  @override
  Future createIssue(String title, String body, List<String> label) async {
    var response =
        await _client.execute(_adapter.createIssue(title, body, label));
    return true;
  }

  Future deleteIssue(String issueId) async {
    var response = await _client.execute(_adapter.deleteIssue(issueId));
    Map data = response.data;
    if (data.containsKey('errors')) {
      return false;
    }
    await GitIssueDataBase.createInstance().deleteByIssueId(issueId);
    UserCacheManager.removeFavorite(issueId);
    return true;
  }

  @override
  Future<GithubGist> forkConfigGist() async {
    await _client.execute(_adapter.forkConfigGist());
    return await getFavoriteGist();
  }

  @override
  Future<bool> saveConfigGist(Map<String, GithubGistFile> map) async {
    await _client.execute(_adapter.saveConfigGist(map));
    return true;
  }

  @override
  Future<GitUser> doAuthenticated(String token, String username) async {
    var response =
        await _client.execute(_adapter.doAuthenticated(token, username));
    Map data = response.data['data']['user'];

    GithubGist gist = _getFavoriteGist(data['gists']['nodes']);
    if (gist != null) {
      UserCacheManager.saveFavoriteGist(gist);
    } else {
      var githubGist = await forkConfigGist();
      UserCacheManager.saveFavoriteGist(githubGist);
    }
    return GithubV4User.fromJson(data);
  }

  @override
  Future starRepo(String owner, String repoName) async {
    await _client.execute(_adapter.starRepo(owner, repoName));
    return true;
  }

  @override
  Future<bool> signIn(String username, String password) async {
    var _githubApi = GithubApi();
    var str = await _githubApi.signIn(username, password);
    if (str == '') {
      return false;
    }
    UserCacheManager.saveToken(str, username);
    return true;
  }

  GithubGist _getFavoriteGist(List list) {
    GithubGist gist;
    list.forEach((map) {
      if ((map['isPublic'] == true) && (map['isFork'] == true)) {
        List files = map['files'];
        for (var fileMap in files) {
          if (fileMap['name'] == favorite_gist_file_name) {
            gist = GithubGist()
              ..name = map['name']
              ..isPublic = true
              ..isFork = true;
            Map<String, String> files = Map();
            files[favorite_gist_file_name] = fileMap['text'];
            gist.files = files;
            GitGistCacheManager.configId = gist.name;
            GitGistCacheManager.configDescription = map['description'];
            return;
          }
        }
      }
    });
    return gist;
  }

  @override
  Future<LabelInfo> getLabelsConfig() async {
    var response =
        await _client.execute(_adapter.getRepoFile(server_label_file));
    String content = response.data['content'];
    content = Utf8Decoder().convert(base64Decode(content.replaceAll("\n", '')));
    var labelInfo = LabelInfo.fromJson(jsonDecode(content));
    return labelInfo;
  }

  @override
  Future getOfficialMessageList() async {
    var response =
        await _client.execute(_adapter.getRepoFile(server_messages_file));
    String content = response.data['content'];
    content = Utf8Decoder().convert(base64Decode(content.replaceAll("\n", '')));
    List list = jsonDecode(content);
    var files =
        list.map<GithubMessage>((map) => GithubMessage.fromJson(map)).toList();
    return files;
  }

  @override
  Future<String> getOfficialMessage(String path) async {
    var response = await _client.execute(_adapter.getRepoFile(path));
    String content = response.data['content'];
    content = Utf8Decoder().convert(base64Decode(content.replaceAll("\n", '')));
    return content;
  }

  @override
  Future<int> getUserIssuesCount(String login) async {
    var response = await _client.execute(_adapter.getUserIssuesCount(login));
    if (response.data.containsKey('errors')) {
      return 0;
    }
    int count = response.data['data']['repository']['issues']['totalCount'];
    UserCacheManager.updateIssuesCount(count);
    return count;
  }
}
