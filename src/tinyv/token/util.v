module token

// NOTE: add keyword tokens here
[direct_array_access]
pub fn keyword_to_token(name string) Token {
	match name.len {
		2 {
			match name[0] {
				`a` {
					match name[1] {
						`s` { return .key_as }
						else { return .unknown }
					}
				}
				`f` {
					match name[1] {
						`n` { return .key_fn }
						else { return .unknown }
					}
				}
				`g` {
					match name[1] {
						`o` { return .key_go }
						else { return .unknown }
					}
				}
				`i` {
					match name[1] {
						`f` { return .key_if }
						`n` { return .key_in }
						`s` { return .key_is }
						else { return .unknown }
					}
				}
				`o` {
					match name[1] {
						`r` { return .key_or }
						else { return .unknown }
					}
				}
				else {
					return .unknown
				}
			}
			return .unknown
		}
		3 {
			match name[0] {
				`a` {
					match name[1] {
						`s` {
							match name[2] {
								`m` { return .key_asm }
								else { return .unknown }
							}
						}
						else {
							return .unknown
						}
					}
				}
				`f` {
					match name[1] {
						`o` {
							match name[2] {
								`r` { return .key_for }
								else { return .unknown }
							}
						}
						else {
							return .unknown
						}
					}
				}
				`m` {
					match name[1] {
						`u` {
							match name[2] {
								`t` { return .key_mut }
								else { return .unknown }
							}
						}
						else {
							return .unknown
						}
					}
				}
				`n` {
					match name[1] {
						`i` {
							match name[2] {
								`l` { return .key_nil }
								else { return .unknown }
							}
						}
						else {
							return .unknown
						}
					}
				}
				`p` {
					match name[1] {
						`u` {
							match name[2] {
								`b` { return .key_pub }
								else { return .unknown }
							}
						}
						else {
							return .unknown
						}
					}
				}
				else {
					return .unknown
				}
			}
			return .unknown
		}
		4 {
			match name[0] {
				`d` {
					match name[1] {
						`u` {
							match name[2] {
								`m` {
									match name[3] {
										`p` { return .key_dump }
										else { return .unknown }
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`e` {
					match name[1] {
						`l` {
							match name[2] {
								`s` {
									match name[3] {
										`e` { return .key_else }
										else { return .unknown }
									}
								}
								else {
									return .unknown
								}
							}
						}
						`n` {
							match name[2] {
								`u` {
									match name[3] {
										`m` { return .key_enum }
										else { return .unknown }
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`g` {
					match name[1] {
						`o` {
							match name[2] {
								`t` {
									match name[3] {
										`o` { return .key_goto }
										else { return .unknown }
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`l` {
					match name[1] {
						`o` {
							match name[2] {
								`c` {
									match name[3] {
										`k` { return .key_lock }
										else { return .unknown }
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`n` {
					match name[1] {
						`o` {
							match name[2] {
								`n` {
									match name[3] {
										`e` { return .key_none }
										else { return .unknown }
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`t` {
					match name[1] {
						`r` {
							match name[2] {
								`u` {
									match name[3] {
										`e` { return .key_true }
										else { return .unknown }
									}
								}
								else {
									return .unknown
								}
							}
						}
						`y` {
							match name[2] {
								`p` {
									match name[3] {
										`e` { return .key_type }
										else { return .unknown }
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				else {
					return .unknown
				}
			}
		}
		5 {
			match name[0] {
				`b` {
					match name[1] {
						`r` {
							match name[2] {
								`e` {
									match name[3] {
										`a` {
											match name[4] {
												`k` { return .key_break }
												else { return .unknown }
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`c` {
					match name[1] {
						`o` {
							match name[2] {
								`n` {
									match name[3] {
										`s` {
											match name[4] {
												`t` { return .key_const }
												else { return .unknown }
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`d` {
					match name[1] {
						`e` {
							match name[2] {
								`f` {
									match name[3] {
										`e` {
											match name[4] {
												`r` { return .key_defer }
												else { return .unknown }
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`f` {
					match name[1] {
						`a` {
							match name[2] {
								`l` {
									match name[3] {
										`s` {
											match name[4] {
												`e` { return .key_false }
												else { return .unknown }
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`m` {
					match name[1] {
						`a` {
							match name[2] {
								`t` {
									match name[3] {
										`c` {
											match name[4] {
												`h` { return .key_match }
												else { return .unknown }
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`r` {
					match name[1] {
						`l` {
							match name[2] {
								`o` {
									match name[3] {
										`c` {
											match name[4] {
												`k` { return .key_rlock }
												else { return .unknown }
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`s` {
					match name[1] {
						`p` {
							match name[2] {
								`a` {
									match name[3] {
										`w` {
											match name[4] {
												`n` { return .key_spawn }
												else { return .unknown }
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`u` {
					match name[1] {
						`n` {
							match name[2] {
								`i` {
									match name[3] {
										`o` {
											match name[4] {
												`n` { return .key_union }
												else { return .unknown }
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				else {
					return .unknown
				}
			}
		}
		6 {
			match name[0] {
				`a` {
					match name[1] {
						`s` {
							match name[2] {
								`s` {
									match name[3] {
										`e` {
											match name[4] {
												`r` {
													match name[5] {
														`t` { return .key_assert }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						`t` {
							match name[2] {
								`o` {
									match name[3] {
										`m` {
											match name[4] {
												`i` {
													match name[5] {
														`c` { return .key_atomic }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`i` {
					match name[1] {
						`m` {
							match name[2] {
								`p` {
									match name[3] {
										`o` {
											match name[4] {
												`r` {
													match name[5] {
														`t` { return .key_import }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`m` {
					match name[1] {
						`o` {
							match name[2] {
								`d` {
									match name[3] {
										`u` {
											match name[4] {
												`l` {
													match name[5] {
														`e` { return .key_module }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`r` {
					match name[1] {
						`e` {
							match name[2] {
								`t` {
									match name[3] {
										`u` {
											match name[4] {
												`r` {
													match name[5] {
														`n` { return .key_return }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`s` {
					match name[1] {
						`e` {
							match name[2] {
								`l` {
									match name[3] {
										`e` {
											match name[4] {
												`c` {
													match name[5] {
														`t` { return .key_select }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						`h` {
							match name[2] {
								`a` {
									match name[3] {
										`r` {
											match name[4] {
												`e` {
													match name[5] {
														`d` { return .key_shared }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						`i` {
							match name[2] {
								`z` {
									match name[3] {
										`e` {
											match name[4] {
												`o` {
													match name[5] {
														`f` { return .key_sizeof }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						`t` {
							match name[2] {
								`a` {
									match name[3] {
										`t` {
											match name[4] {
												`i` {
													match name[5] {
														`c` { return .key_static }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								`r` {
									match name[3] {
										`u` {
											match name[4] {
												`c` {
													match name[5] {
														`t` { return .key_struct }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`t` {
					match name[1] {
						`y` {
							match name[2] {
								`p` {
									match name[3] {
										`e` {
											match name[4] {
												`o` {
													match name[5] {
														`f` { return .key_typeof }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`u` {
					match name[1] {
						`n` {
							match name[2] {
								`s` {
									match name[3] {
										`a` {
											match name[4] {
												`f` {
													match name[5] {
														`e` { return .key_unsafe }
														else { return .unknown }
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				else {
					return .unknown
				}
			}
		}
		8 {
			match name[0] {
				`_` {
					match name[1] {
						`_` {
							match name[2] {
								`g` {
									match name[3] {
										`l` {
											match name[4] {
												`o` {
													match name[5] {
														`b` {
															match name[6] {
																`a` {
																	match name[7] {
																		`l` { return .key_global }
																		else { return .unknown }
																	}
																}
																else {
																	return .unknown
																}
															}
														}
														else {
															return .unknown
														}
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						`l` {
							match name[2] {
								`i` {
									match name[3] {
										`k` {
											match name[4] {
												`e` {
													match name[5] {
														`l` {
															match name[6] {
																`y` {
																	match name[7] {
																		`_` { return .key_likely }
																		else { return .unknown }
																	}
																}
																else {
																	return .unknown
																}
															}
														}
														else {
															return .unknown
														}
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`c` {
					match name[1] {
						`o` {
							match name[2] {
								`n` {
									match name[3] {
										`t` {
											match name[4] {
												`i` {
													match name[5] {
														`n` {
															match name[6] {
																`u` {
																	match name[7] {
																		`e` { return .key_continue }
																		else { return .unknown }
																	}
																}
																else {
																	return .unknown
																}
															}
														}
														else {
															return .unknown
														}
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				`v` {
					match name[1] {
						`o` {
							match name[2] {
								`l` {
									match name[3] {
										`a` {
											match name[4] {
												`t` {
													match name[5] {
														`i` {
															match name[6] {
																`l` {
																	match name[7] {
																		`e` { return .key_volatile }
																		else { return .unknown }
																	}
																}
																else {
																	return .unknown
																}
															}
														}
														else {
															return .unknown
														}
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				else {
					return .unknown
				}
			}
		}
		9 {
			match name[0] {
				`i` {
					match name[1] {
						`n` {
							match name[2] {
								`t` {
									match name[3] {
										`e` {
											match name[4] {
												`r` {
													match name[5] {
														`f` {
															match name[6] {
																`a` {
																	match name[7] {
																		`c` {
																			match name[8] {
																				`e` { return .key_interface }
																				else { return .unknown }
																			}
																		}
																		else {
																			return .unknown
																		}
																	}
																}
																else {
																	return .unknown
																}
															}
														}
														else {
															return .unknown
														}
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						`s` {
							match name[2] {
								`r` {
									match name[3] {
										`e` {
											match name[4] {
												`f` {
													match name[5] {
														`t` {
															match name[6] {
																`y` {
																	match name[7] {
																		`p` {
																			match name[8] {
																				`e` { return .key_isreftype }
																				else { return .unknown }
																			}
																		}
																		else {
																			return .unknown
																		}
																	}
																}
																else {
																	return .unknown
																}
															}
														}
														else {
															return .unknown
														}
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				else {
					return .unknown
				}
			}
		}
		10 {
			match name[0] {
				`_` {
					match name[1] {
						`_` {
							match name[2] {
								`o` {
									match name[3] {
										`f` {
											match name[4] {
												`f` {
													match name[5] {
														`s` {
															match name[6] {
																`e` {
																	match name[7] {
																		`t` {
																			match name[8] {
																				`o` {
																					match name[9] {
																						`f` { return .key_offsetof }
																						else { return .unknown }
																					}
																				}
																				else {
																					return .unknown
																				}
																			}
																		}
																		else {
																			return .unknown
																		}
																	}
																}
																else {
																	return .unknown
																}
															}
														}
														else {
															return .unknown
														}
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						`u` {
							match name[2] {
								`n` {
									match name[3] {
										`l` {
											match name[4] {
												`i` {
													match name[5] {
														`k` {
															match name[6] {
																`e` {
																	match name[7] {
																		`l` {
																			match name[8] {
																				`y` {
																					match name[9] {
																						`_` { return .key_unlikely }
																						else { return .unknown }
																					}
																				}
																				else {
																					return .unknown
																				}
																			}
																		}
																		else {
																			return .unknown
																		}
																	}
																}
																else {
																	return .unknown
																}
															}
														}
														else {
															return .unknown
														}
													}
												}
												else {
													return .unknown
												}
											}
										}
										else {
											return .unknown
										}
									}
								}
								else {
									return .unknown
								}
							}
						}
						else {
							return .unknown
						}
					}
				}
				else {
					return .unknown
				}
			}
		}
		else {
			return .unknown
		}
	}
}
